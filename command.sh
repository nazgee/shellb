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

if [[ -n "${SHELB_DEVEL_DIR}" ]]; then
  # shellcheck source=core.sh
  source core.sh
fi

_SHELLB_DB_COMMANDS="${_SHELLB_DB}/commands"
[ ! -e "${_SHELLB_DB_COMMANDS}" ] && mkdir -p "${_SHELLB_DB_COMMANDS}"

###############################################
# command functions - basic
###############################################

function _shellb_command_generate_filename() {
  _shellb_print_dbg "_shellb_command_generate_filename()"
  local cmd_file
  cmd_file="$(uuidgen -t)"
  echo "${cmd_file}.${_SHELLB_CFG_COMMAND_EXT}"
}

# List abs command files matching given command in given dir
# $1 - command to match
# $2 - user dir to search for already installed commands
function _shellb_command_list_matching() {
  _shellb_print_dbg "_shellb_command_list_matching($*)"
  local target user_dir domain_dir available_cmd_files
  target="${1}"
  user_dir="${2}"
  domain_dir=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_COMMANDS}")

  mapfile -t available_cmd_files < <(_shellb_core_domain_files_ls "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${user_dir}")
  for cmd_file in "${available_cmd_files[@]}"; do
    if _shellb_core_is_same_as_file "${target}" "${domain_dir}/${cmd_file}"; then
      echo "${domain_dir}/${cmd_file}"
    fi
  done
}

# List command files matching given command under given dir
# $1 - command to match
# $2 - user dir to search for already installed commands
function _shellb_command_find_matching() {
  local target user_dir available_cmd_files
  target="${1}"
  user_dir="${2}"

  mapfile -t available_cmd_files < <(_shellb_core_domain_files_find "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${user_dir}")
  for cmd_file in "${available_cmd_files[@]}"; do
    if _shellb_core_is_same_as_file "${target}" "${domain_dir}/${cmd_file}"; then
      echo "${domain_dir}/${cmd_file}"
    fi
  done
}

# Save given command for a given user dir.
# ${1} - command string
# ${2} - optional: directory to save command for (default is current dir)
function _shellb_command_save() {
  _shellb_print_dbg "shellb_command_save($*)"
  local command_string user_dir domain_dir matched_command_files cmd_file cmd_absfile cmd_domainfile
  command_string="${1}"
  user_dir="$(realpath -eq "${2:-.}" 2>/dev/null)" || _shellb_print_err "\"${2:-.}\" is not a valid dir" || return 1
  domain_dir=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_COMMANDS}")

  # check if command is already installed, and exit if it is
  mapfile -t matched_command_files < <(_shellb_command_list_matching "${command_string}" "${user_dir}")
  if [ ${#matched_command_files[@]} -gt 0 ]; then
    _shellb_print_wrn "command <${command_string}> is already available for ${user_dir}, skipping"
    return 0
  fi
  cmd_file="$(_shellb_command_generate_filename)"

  mkdir -p "${domain_dir}" || _shellb_print_wrn_fail "failed to create directory \"${domain_dir}\" for <${command_string}> command" || return 1
  echo "${command_string}" > "${domain_dir}/${cmd_file}" || _shellb_print_wrn_fail "failed to save command <${command_string}> to \"${domain_dir}/${cmd_file}\"" || return 1
}

# Show prompt with current command, and allow user to edit it
# command will be saved if user confirms with ENTER
# ${1} - optional: directory to save command for (default is current dir)
# ${2} - optional: command string to edit (can be empty)
function _shellb_command_edit() {
  local user_dir command_string
  user_dir="${1:-.}"
  command_string="${2}"
  read -e -p "$ " -i "${command_string}" command_string || return 1
  _shellb_command_save "${command_string}" "${user_dir}"
}

# ${1} - directory to save command for. default is current dir
function shellb_command_save_previous() {
  local command_string user_dir
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || _shellb_print_err "\"${1:-.}\" is not a valid dir" || return 1
  command_string=$(history | tail -n 2 | head -n 1 | sed 's/[0-9 ]*//')
  _shellb_print_nfo "save previous command for \"${user_dir}\" (edit & confirm with ENTER, cancel with ctrl-c)"
  _shellb_command_edit "${user_dir}" "${command_string}"
}

# ${1} - directory to save command for. default is current dir
function shellb_command_save_interactive() {
  local command_string user_dir
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || _shellb_print_err "\"${1:-.}\" is not a valid dir" || return 1
  _shellb_print_nfo "save new command for \"${user_dir}\" (edit & confirm with ENTER, cancel with ctrl-c)"
  _shellb_command_edit "${user_dir}" "${command_string}"
}

# ${1} command to execute
function _shellb_command_exec() {
  _shellb_print_dbg "_shellb_command_exec($*)"
  local target="${1}"
  eval "${target}"
}

###############################################
# command functions - list
###############################################

# Lists commands in given directory, or returns 1 if none found or given dir is invalid
# $1 - user directory to list command for (default: current dir)
function shellb_command_list() {
  _shellb_print_dbg "shellb_command_list($*)"

  # parse args, init variables and do sanity checks
  local user_dir domain_dir_abs domain_dir_proto command_file i=0
  user_dir=$(realpath -qe "${1:-.}" 2>/dev/null) || _shellb_print_err "\"${1}\" is not a valid dir" || return 1
  [ -d "${user_dir}" ] || _shellb_print_err "command list failed, \"${user_dir}\" is not a dir" || return 1
  domain_dir_abs=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_COMMANDS}")
  domain_dir_proto=$(_shellb_core_calc_domainrel_from_abs "${domain_dir_abs}" "${_SHELLB_DB_COMMANDS}")

  # fetch all commands under given domain dir
  mapfile -t matched_commands < <(_shellb_core_domain_files_ls "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${user_dir}")
  # check if any commands were found
  [ ${#matched_commands[@]} -gt 0 ] || _shellb_print_err "no commands in \"${domain_dir_proto}\"" || return 1

  # print commands
  _shellb_print_nfo "commands in ${domain_dir_proto}"
  for command_file in "${matched_commands[@]}"; do
    i=$((i+1))
    printf "%3s) | %s | %s\n" "${i}" "$(basename "${command_file}")" "$(cat "${domain_dir_abs}/${command_file}")"
  done
}

# Open a list of commands installed for given dir, and allow user to select which one should executed
# $1 - optional directory to list command for (default: current dir)
function shellb_command_list_exec() {
  _shellb_print_dbg "shellb_command_list_exec($*)"
  local list target selection user_dir
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || _shellb_print_err "\"${1:-.}\" is not a valid dir" || return 1

  list=$(shellb_command_list "${user_dir}") || return 1
  echo "${list}"
  _shellb_print_nfo "select command to execute:"

  read -r selection || return 1
  target="$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 3)"

  [ -n "${target}" ] || _shellb_print_err "command list exec failed, no command" || return 1
  _shellb_print_nfo "execute command (edit & confirm with ENTER or cancel with ctrl-c):"
  read -r -e -p "$ " -i "${target}" target && history -s "${target}" && _shellb_command_exec "${target}"
}

# Open a list of commands installed for given dir, and allow user to select which one should edited
# $1 - optional directory to list command for (default: current dir)
function shellb_command_list_edit() {
  _shellb_print_dbg "shellb_command_list_edit($*)"
  local list command_string selection user_dir
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || _shellb_print_err "\"${1:-.}\" is not a valid dir" || return 1

  list=$(shellb_command_list "${user_dir}") || return 1
  echo "${list}"
  _shellb_print_nfo "select command to edit:"

  read -r selection || return 1
  command_string="$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 3)"

  [ -n "${command_string}" ] || _shellb_print_err "command list edit failed, no command" || return 1

  mapfile -t matching_cmd_files < <(_shellb_command_list_matching "${command_string}" "${user_dir}")

  [ ${#matched_command_files[@]} -eq 0 ] || _shellb_print_err "command list edit failed, command file not found" || return 1

  # check if multiple files are matching the command
  local cmd_file_index
  cmd_file_index=0
  if [ ${#matched_command_files[@]} -gt 1 ]; then
    _shellb_print_wrn "command <${command_string}> is defined multiple times, please choose which one to edit:"
    # TODO implement
    _shellb_print_err "not unimplemented"
    return 0
  fi

  local edit_target_proto edit_target_abs
  edit_target_abs="${matching_cmd_files[${cmd_file_index}]}"
  edit_target_proto=$(_shellb_core_calc_domainrel_from_abs "${edit_target_abs}" "${_SHELLB_DB_COMMANDS}")

  _shellb_print_nfo "edit command (edit & confirm with ENTER or cancel with ctrl-c)"
  _shellb_command_edit "${user_dir}" "${command_string}" && rm "${edit_target_abs}"
}

# Open a list of commands installed for given dir, and allow user to select which one should be deleted
# $1 - optional directory to list command for (default: current dir)
function shellb_command_list_del() {
  _shellb_print_dbg "shellb_command_list_del($*)"
  local list target selection user_dir domain_dir target_cmd matching_cmd_files
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || _shellb_print_err "\"${1:-.}\" is not a valid dir" || return 1
  domain_dir=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_COMMANDS}")

  list=$(shellb_command_list "${user_dir}") || return 1
  echo "${list}"
  if [ "$(echo "${list}" | wc -l)" -gt 2 ]; then
    _shellb_print_nfo "select command to delete:"
    read -r selection || return 1
  else
    selection=1
  fi
  target="$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 3)"

  mapfile -t matching_cmd_files < <(_shellb_command_list_matching "${target}" "${user_dir}")

  for cmd_file in "${matching_cmd_files[@]}"; do
    local proto_target
    proto_target=$(_shellb_core_calc_domainrel_from_abs "${cmd_file}" "${_SHELLB_DB_COMMANDS}")
    _shellb_print_nfo "command file: \"${proto_target}\""
    _shellb_core_get_user_confirmation "delete command \"$(cat "${cmd_file}")\"?" || return 0
    rm "${cmd_file}"
  done

  _shellb_print_nfo "command deleted: ${target}"
}

###############################################
# command functions - find
###############################################

# Lists commands below given directory, or returns 1 if none found or given dir is invalid
# $1 - user directory to list command for (default: current dir)
function shellb_command_find() {
  _shellb_print_dbg "shellb_command_find($*)"

  # parse args, init variables and do sanity checks
  local user_dir domain_dir_abs domain_dir_proto command_file i=0
  user_dir=$(realpath -qe "${1:-.}" 2>/dev/null) || _shellb_print_err "\"${1}\" is not a valid dir" || return 1
  [ -d "${user_dir}" ] || _shellb_print_err "command list failed, \"${user_dir}\" is not a dir" || return 1
  domain_dir_abs=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_COMMANDS}")
  domain_dir_proto=$(_shellb_core_calc_domainrel_from_abs "${domain_dir_abs}" "${_SHELLB_DB_COMMANDS}")

  # fetch all commands under given domain dir
  mapfile -t matched_commands < <(_shellb_core_domain_files_find "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${user_dir}")
  # check if any commands were found
  [ ${#matched_commands[@]} -gt 0 ] || _shellb_print_err "no commands below \"${domain_dir_proto}\"" || return 1

  # print commands
  _shellb_print_nfo "commands below ${domain_dir_proto}"
  for command_file in "${matched_commands[@]}"; do
    i=$((i+1))
    printf "%3s) | %s | %s\n" "${i}" "$(basename "${command_file}")" "$(cat "${domain_dir_abs}/${command_file}")"
  done
}

# TODO add to shotrcuts/config
function shellb_command_find_exec() {
  _shellb_print_dbg "shellb_command_list_exec($*)"
  local list target selection user_dir
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || _shellb_print_err "\"${1:-.}\" is not a valid dir" || return 1

  list=$(shellb_command_find "${user_dir}") || return 1
  echo "${list}"
  _shellb_print_nfo "select command to execute:"

  read -r selection || return 1
  target="$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 3)"

  [ -n "${target}" ] || _shellb_print_err "command list exec failed, no command" || return 1
  _shellb_print_nfo "execute command (edit & confirm with ENTER or cancel with ctrl-c):"
  read -r -e -p "$ " -i "${target}" target && history -s "${target}" && _shellb_command_exec "${target}"
}

# TODO add to shotrcuts/config
function shellb_command_find_del() {
  _shellb_print_dbg "shellb_command_list_del($*)"
  local list target selection user_dir domain_dir target_cmd matching_cmd_files
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || _shellb_print_err "\"${1:-.}\" is not a valid dir" || return 1
  domain_dir=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_COMMANDS}")

  list=$(shellb_command_find "${user_dir}") || return 1
  echo "${list}"
  if [ "$(echo "${list}" | wc -l)" -gt 2 ]; then
    _shellb_print_nfo "select command to delete:"
    read -r selection || return 1
  else
    selection=1
  fi
  target="$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 3)"

  mapfile -t matching_cmd_files < <(_shellb_command_find_matching "${target}" "${user_dir}")
  for cmd_file in "${matching_cmd_files[@]}"; do
    local proto_target
    proto_target=$(_shellb_core_calc_domainrel_from_abs "${cmd_file}" "${_SHELLB_DB_COMMANDS}")
    _shellb_print_nfo "command file: \"${proto_target}\""
    _shellb_core_get_user_confirmation "delete command \"$(cat "${cmd_file}")\"?" || return 0
    rm "${cmd_file}"
  done

  _shellb_print_nfo "command deleted: ${target}"
}

###############################################
# command functions - compgen
###############################################

_SHELLB_COMMAND_ACTIONS="new save del run edit list purge"

function _shellb_command_action() {
  _shellb_print_dbg "_shellb_command_action($*)"
  local action
  action=$1
  shift
  [ -n "${action}" ] || _shellb_print_err "no action given" || return 1

  case ${action} in
    help)
    _shellb_print_err "unimplemented \"command $action\""
      ;;
    new)
      shellb_command_save_interactive "$@"
      ;;
    save)
      shellb_command_save_previous "$@"
      ;;
    del)
      local arg="$1"
      shift
      case "${arg}" in
        -a|--all)
          shellb_command_find_del "/"
          ;;
        -c|--current)
          shellb_command_list_del "$@"
          ;;
        -r|--recursive)
          shellb_command_find_del "$@"
          ;;
        *)
          _shellb_print_err "unknown scope \"${arg}\" passed to \"command $action\""
          return 1
          ;;
      esac
      ;;
    run)
      local arg="$1"
      shift
      case "${arg}" in
        -a|--all)
          shellb_command_find_exec "/"
          ;;
        -c|--current)
          shellb_command_list_exec "$@"
          ;;
        -r|--recursive)
          shellb_command_find_exec "$@"
          ;;
        *)
          _shellb_print_err "unknown scope \"${arg}\" passed to \"command $action\""
          return 1
          ;;
      esac
      ;;
    edit)
      local arg="$1"
      shift
      case "${arg}" in
        -a|--all)
          _shellb_print_err "unimplemented \"command $action\""
          ;;
        -c|--current)
          shellb_command_list_edit "$@"
          ;;
        -r|--recursive)
          _shellb_print_err "unimplemented \"command $action\""
          ;;
        *)
          _shellb_print_err "unknown scope \"${arg}\" passed to \"command $action\""
          return 1
          ;;
      esac
      ;;
    list)
      local arg="$1"
      shift
      case "${arg}" in
        -a|--all)
          shellb_command_find "/"
          ;;
        -c|--current)
          shellb_command_list "$@"
          ;;
        -r|--recursive)
          shellb_command_find "$@"
          ;;
        *)
          _shellb_print_err "unknown scope \"${arg}\" passed to \"command $action\""
          return 1
          ;;
      esac
      ;;
    purge)
      _shellb_print_err "unimplemented \"command $action\""
      ;;
    *)
      _shellb_print_err "unknown action \"command $action\""
      ;;
  esac
}

function _shellb_command_list_compgen() {
  _shellb_core_compgen "${_SHELLB_DB_COMMANDS}" "" "" ""
}

function _shellb_command_compgen() {
  _shellb_print_dbg "_shellb_command_compgen($*)"

  local comp_cur opts action arg
  comp_cur="${COMP_WORDS[COMP_CWORD]}"
  _shellb_print_dbg "comp_cur: \"${comp_cur}\" COMP_CWORD: \"${COMP_CWORD}\""

  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()

  case $((COMP_CWORD)) in
    2)
      opts="${_SHELLB_COMMAND_ACTIONS} help"
      ;;
    3)
      action="${COMP_WORDS[2]}"
      case "${action}" in
        help)
          opts="${_SHELLB_COMMAND_ACTIONS}"
          ;;
        new)
          _shellb_command_list_compgen
          return
          ;;
        save)
          _shellb_command_list_compgen
          return
          ;;
        del)
          opts="--current --all --recursive -a -c -r"
          ;;
        run)
          opts="--current --all --recursive -a -c -r"
          ;;
        edit)
          opts=""
          ;;
        list)
          opts="--current --all --recursive -a -c -r"
          ;;
        purge)
          opts=""
          ;;
        *)
          _shellb_print_wrn "unknown command \"${comp_cur}\""
          opts=""
          ;;
      esac
      ;;
    *)
      action="${COMP_WORDS[3]}"
      arg="${COMP_WORDS[4]}"
      case "${action}" in
        help)
          opts=${_SHELLB_COMMAND_ACTIONS}
          ;;
        new)
          opts=""
          ;;
        save)
          opts=""
          ;;
        del)
          case "${arg}" in
            -a|--all)
              opts=""
              ;;
            -c|--current)
              _shellb_command_list_compgen
              return
              ;;
            -r|--recursive)
              _shellb_command_list_compgen
              return
              ;;
            *)
              opts=""
              ;;
          esac
          ;;
        run)
          case "${arg}" in
            -a|--all)
              opts=""
              ;;
            -c|--current)
              _shellb_command_list_compgen
              return
              ;;
            -r|--recursive)
              _shellb_command_list_compgen
              return
              ;;
            *)
              opts=""
              ;;
          esac
          ;;
        edit)
          opts=""
          ;;
        list)
          case "${arg}" in
            -a|--all)
              opts=""
              ;;
            -c|--current)
              _shellb_command_list_compgen
              return
              ;;
            -r|--recursive)
              _shellb_command_list_compgen
              return
              ;;
            *)
              opts=""
              ;;
          esac
          ;;
        purge)
          opts=""
          ;;
        *)
          _shellb_print_wrn "unknown command \"${comp_cur}\""
          opts=""
          ;;
      esac
      ;;
  esac

  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
}