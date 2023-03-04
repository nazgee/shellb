# detects if the script is being sourced or not. exit if run directly, instead of being sourced
(
  [[ -n $ZSH_VERSION && $ZSH_EVAL_CONTEXT =~ :file$ ]] ||
  [[ -n $KSH_VERSION && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]] ||
  [[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)
) && sourced=1 || sourced=0

if [ $sourced -eq 0 ]; then
  echo "This script must be sourced by shellb. Do not run it directly"
  exit 1
fi

echo "command extension loading..."

if [[ -n "${SHELB_DEVEL_DIR}" ]]; then
  # shellcheck source=core.sh
  source core.sh
fi

_SHELLB_DB_COMMANDS="${_SHELLB_DB}/commands"
[ ! -e "${_SHELLB_DB_COMMANDS}" ] && mkdir -p "${_SHELLB_DB_COMMANDS}"

###############################################
# command functions
###############################################
# ${1} - optional directory to calculate command dir for
function _shellb_command_calc_absdir() {
  _shellb_print_dbg "_shellb_command_calc_absdir($*)"
  _shellb_core_calc_absdir "${_SHELLB_DB_COMMANDS}" "${1}"
}

# ${1} - command file name
# ${2} - optional directory to calculate command file for
function _shellb_command_calc_absfile() {
  _shellb_print_dbg "_shellb_command_calc_absfile($*)"
  _shellb_core_calc_absfile "${1}" "${_SHELLB_DB_COMMANDS}" "${2}"
}

# ${1} - command file name
# ${2} - optional directory to calculate command file for
function _shellb_command_calc_domainfile() {
  _shellb_print_dbg "_shellb_command_calc_domainfile($*)"
  local command_absfile
  command_absfile="$(_shellb_command_calc_absfile "${1}" "${2}")"
  echo "${_SHELLB_CFG_PROTO}$(_shellb_core_calc_domainfile "${command_absfile}" "${_SHELLB_DB_COMMANDS}")"
}

# ${1} - optional directory to calculate command dir for
function _shellb_command_calc_domaindir() {
  _shellb_print_dbg "_shellb_command_calc_domaindir($*)"
  local command_absdir
  command_absdir="$(_shellb_command_calc_absdir "${1}")"
  echo "${_SHELLB_CFG_PROTO}$(_shellb_core_calc_domaindir "${_SHELLB_DB_COMMANDS}" "${command_absdir}")"
}

function _shellb_command_list_column() {
  _shellb_core_list_as_column "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${1}" | sort
}

function _shellb_command_list_column_unique() {
  _shellb_command_list_column "${1}" | uniq
}

function _shellb_command_list_row() {
  _shellb_core_list_as_row "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${1}"  && echo ""
}

function _shellb_command_find_column() {
  _shellb_core_find_as_column "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${1}" | sort
}

function _shellb_command_find_column_unique() {
  _shellb_command_find_column "${1}" | uniq
}

function _shellb_command_find_row() {
  _shellb_core_find_as_row "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${1}"  && echo ""
}

function _shellb_command_generate_filename() {
  _shellb_print_dbg "_shellb_command_generate_filename()"
  local cmd_file
  cmd_file="$(uuidgen -t)"
  echo "${cmd_file}.${_SHELLB_CFG_COMMAND_EXT}"
}

# ${1} - command string
# ${2} - directory to save command for
function _shellb_command_save() {
  _shellb_print_dbg "shellb_command_save($*)"
  local command_string user_dir cmd_file cmd_asbfile cmd_domainfile
  command_string="${1}"
  user_dir="${2}"
  cmd_file="$(_shellb_command_generate_filename)"
  cmd_absfile="$(_shellb_command_calc_absfile "${cmd_file}" "${user_dir}")"
  cmd_domainfile="$(_shellb_command_calc_domainfile "${cmd_file}" "${user_dir}")"

  _shellb_print_dbg "saving command: <${command_string}> to ${cmd_domainfile} / ${cmd_absfile}"
  mkdir -p "$(dirname "${cmd_absfile}")" || _shellb_print_wrn_fail "failed to create directory \"${cmd_absfile}\" for <${command_string}> command" || return 1
  echo "${command_string}" > "${cmd_absfile}" || _shellb_print_wrn_fail "failed to save command <${command_string}> to \"${cmd_absfile}\"" || return 1
}

# ${1} - directory to save command for. default is current dir
function shellb_command_save_previous() {
  local command_string user_dir
  user_dir="${1:-.}"
  command_string=$(history | tail -n 2 | head -n 1 | sed 's/[0-9 ]*//')
  _shellb_print_nfo "saving previous command: (edit & confirm with ENTER or cancel with ctrl-c)"
  read -e -p "$ " -i "${command_string}" command_string
  _shellb_command_save "${command_string}" "${user_dir}"
}

# ${1} - directory to save command for. default is current dir
function shellb_command_save_interactive() {
  local command_string user_dir
  user_dir="${1:-.}"
  _shellb_print_nfo "saving previous command (edit & confirm with ENTER or cancel with ctrl-c):"
  read -r -e -p "$ " command_string || return 1
  _shellb_command_save "${command_string}" "${user_dir}"
}

function _shellb_command_list_print_menu() {
  _shellb_print_dbg "_shellb_command_list_print_menu($*)"
  local cmd_absdir user_dir seen i=1
  seen=0
  user_dir="${1:-.}"
  cmd_absdir="$(_shellb_command_calc_absdir "${user_dir}")"
  while read -r commandfile
  do
    seen=1
    # display only the part of the path that is not the commands directory
    printf "%3s) %s\n" "${i}" "$(cat "${cmd_absdir}/${commandfile}")"
    i=$(($i+1))
  done < <(_shellb_command_list_column_unique "${user_dir}") || return 1

  # if no commands seen, return error
  [ "${seen}" -eq 1 ] || return 1
}

# TODO add to shotrcuts/config
function shellb_command_list() {
  _shellb_print_dbg "shellb_command_list($*)"
  local commands_list user_dir command_domaindir

  user_dir="${1:-.}"
  command_domaindir="$(_shellb_command_calc_domaindir "${user_dir}")"

  commands_list=$(_shellb_command_list_print_menu "${user_dir}") || _shellb_print_err "command list failed, no commands in \"${command_domaindir}\"" || return 1
  _shellb_print_nfo "commands in \"${command_domaindir}\":"
  echo "${commands_list}"
}

# ${1} command to execute
function _shellb_command_exec() {
  _shellb_print_dbg "_shellb_command_exec($*)"
  local target="${1}"
  eval "${target}"
}

# TODO add to shotrcuts/config
function shellb_command_list_exec() {
  _shellb_print_dbg "shellb_command_list_exec($*)"
  local commands_list target user_dir
  user_dir="${1:-.}"

  commands_list=$(shellb_command_list "${user_dir}") || return 1
  echo "${commands_list}"
  _shellb_print_nfo "select command to execute:"

  # ask user to select a command, but omit the first line (header)
  # from a list that is given to _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_whole "$(echo "${commands_list}" | tail -n +2)")
  _shellb_print_nfo "execute command (edit & confirm with ENTER or cancel with ctrl-c):"
  read -r -e -p "$ " -i "${target}" target && history -s "${target}" && _shellb_command_exec "${target}"
}

# TODO add to shotrcuts/config
function shellb_command_list_del() {
  _shellb_print_dbg "shellb_command_list_del($*)"
  local commands_list user_dir targets target_cmd cmd_absdir
  user_dir="${1:-.}"

  commands_list=$(shellb_command_list "${user_dir}") || return 1
  echo "${commands_list}"
  _shellb_print_nfo "select command to delete:"

  # ask user to select a command, but omit the first line (header)
  # from a list that is given to _shellb_core_get_user_selection
  cmd_absdir="$(_shellb_command_calc_absdir "${user_dir}")"
  target_command=$(_shellb_core_get_user_selection_whole "$(echo "${commands_list}" | tail -n +2)")
  targets=$(_shellb_core_list_files_matching_content_as_column "${target_command}" "${cmd_absdir}" "*.${_SHELLB_CFG_COMMAND_EXT}") \
      || _shellb_print_err "command delete failed, file with \"${target_command}\" not found in \"${cmd_absdir}\"" || return 1

  target_cmd="$(cat "${targets}")"
  rm "${targets}" || _shellb_print_err "command delete failed, could not delete file ${target}" || return 1
  _shellb_print_nfo "command deleted: ${target_cmd}"
}

# TODO add to shotrcuts/config
function _shellb_command_find_print_menu() {
  _shellb_print_dbg "_shellb_command_find_print_menu($*)"
  local cmd_absdir user_dir seen i=1
  seen=0
  user_dir="${1:-.}"
  cmd_absdir="$(_shellb_command_calc_absdir "${user_dir}")"
  while read -r commandfile
  do
    seen=1
    # display only the part of the path that is not the notepad directory
    printf "%3s) %s\n" "${i}" "$(cat "${cmd_absdir}/${commandfile}")"
    i=$(($i+1))
  done < <(_shellb_command_find_column_unique "${user_dir}") || return 1

  # if no notepads seen, return error
  [ "${seen}" -eq 1 ] || return 1
}

# TODO add to shotrcuts/config
function shellb_command_find() {
  _shellb_print_dbg "shellb_command_find($*)"
  local commands_list user_dir command_domaindir

  user_dir="${1:-.}"
  command_domaindir="$(_shellb_command_calc_domaindir "${user_dir}")"
  # if cur is empty, we're completing bookmark name
  commands_list=$(_shellb_command_find_print_menu "${user_dir}") || _shellb_print_err "command find failed, no commands in \"${command_domaindir}\"" || return 1
  _shellb_print_nfo "commands below \"${command_domaindir}\":"
  echo "${commands_list}"
}

# TODO add to shotrcuts/config
function shellb_command_find_exec() {
  _shellb_print_dbg "shellb_command_find_exec($*)"
  local commands_list target user_dir
  user_dir="${1:-.}"

  commands_list=$(shellb_command_find "${user_dir}") || return 1
  echo "${commands_list}"
  _shellb_print_nfo "select command to execute:"

  # ask user to select a command, but omit the first line (header)
  # from a list that is given to _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_whole "$(echo "${commands_list}" | tail -n +2)")
  _shellb_print_nfo "execute command (edit & confirm with ENTER or cancel with ctrl-c):"
  read -r -e -p "$ " -i "${target}" target && history -s "${target}" && _shellb_command_exec "${target}"
}

# TODO add to shotrcuts/config
function shellb_command_find_del() {
  _shellb_print_dbg "shellb_command_find_del($*)"
  local commands_list user_dir target target_cmd
  user_dir="${1:-.}"

  commands_list=$(shellb_command_find "${user_dir}") || return 1
  echo "${commands_list}"
  _shellb_print_nfo "select command to delete:"

  # ask user to select a command, but omit the first line (header)
  # from a list that is given to _shellb_core_get_user_selection
  cmd_absdir="$(_shellb_command_calc_absdir "${user_dir}")"
  target_command=$(_shellb_core_get_user_selection_whole "$(echo "${commands_list}" | tail -n +2)")
  target=$(_shellb_core_find_files_matching_content_as_column "${target_command}" "${cmd_absdir}" "*.${_SHELLB_CFG_COMMAND_EXT}") \
      || _shellb_print_err "command delete failed, file with \"${target_command}\" not found below \"${cmd_absdir}\"" || return 1

  target_cmd="$(cat "${target}")"
  rm "${target}" || _shellb_print_err "command delete failed, could not delete file ${target}" || return 1
  _shellb_print_nfo "command deleted: ${target_cmd}"
}






function _shellb_command_action() {
  _shellb_print_dbg "_shellb_command_action($*)"
  local action
  action=$1
  [ -n "${action}" ] || _shellb_print_err "no action given" || return 1

  case ${action} in
    new)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    save)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    del)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    dellocal)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    run)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    runlocal)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    edit)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    editlocal)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    list)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    listlocal)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    purge)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    *)
      _shellb_print_err "unknown action \"command $action\""
      ;;
  esac
}

function _shellb_command_completion_opts() {
  _shellb_print_dbg "_shellb_command_completion_opts($*)"

  local comp_words comp_cword comp_cur comp_prev opts
  comp_cword=$1
  shift
  comp_words=( $@ )
  comp_cur="${comp_words[$comp_cword]}"
  comp_prev="${comp_words[$comp_cword-1]}"

  case ${comp_cword} in
    1)
      opts="new save del dellocal run runlocal edit editlocal list listlocal purge"
      ;;
    2)
      case "${comp_prev}" in
        new|save|del|dellocal|run|runlocal|edit|editlocal|list|listlocal|purge)
          opts="reallySet"
          ;;
        *)
          _shellb_print_wrn "unknown command \"${comp_cur}\""
          opts=""
          ;;
      esac
      ;;
  esac

  echo "${opts}"
}