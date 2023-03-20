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
  source core.sh 2>/dev/null
fi

_SHELLB_DB_COMMANDS="${_SHELLB_DB}/commands"
[ ! -e "${_SHELLB_DB_COMMANDS}" ] && mkdir -p "${_SHELLB_DB_COMMANDS}"

###############################################
# command functions - basic
###############################################

# Given a user path of a file in the shellb domain
# return it's name translated to shellb proto
function _shellb_command_get_resource_proto_from_user() {
  _shellb_core_calc_domainrel_from_user "${1}" "${_SHELLB_DB_COMMANDS}"
}

# Given a user path of a file in the shellb domain
# return it's name translated to shellb proto
function _shellb_command_get_resource_proto_from_abs() {
  _shellb_core_calc_domainrel_from_abs "${1}" "${_SHELLB_DB_COMMANDS}"
}

# Translate /usr/bar/foo._SHELLB_CFG_COMMAND_EXT to /usr/bar/foo._SHELLB_CFG_COMMAND_TAG_EXT
# ${1} - absolute path to command file
function _shellb_command_get_tagfile_from_commandfile() {
  _shellb_print_dbg "_shellb_command_get_tagfile_from_commandfile($*)"
  local cmd_file uuid_file
  cmd_file="${1}"
  [ -n "${cmd_file}" ] || { _shellb_print_err "cmd_file not given" ; return 1; }
  uuid_file="$(basename "${cmd_file}")"
  uuid_file="${uuid_file%.*}"
  echo "${cmd_file%/*}/${uuid_file}.${_SHELLB_CFG_COMMAND_TAG_EXT}"
}

# Save given command for a given user dir.
# ${1} - command string
# ${2} - command file name
# ${3} - optional: directory to save command for (default is current dir)
function _shellb_command_save() {
  _shellb_print_dbg "_shellb_command_save($*)"
  local command_string user_dir domain_dir cmd_file

  # sanity checks
  command_string="${1}"
  cmd_file="${2}"
  [ -n "${command_string}" ] || { _shellb_print_err "command_string not given" ; return 1; }
  [ -n "${cmd_file}" ] || { _shellb_print_err "cmd_file not given" ; return 1; }
  user_dir="$(realpath -eq "${3:-.}" 2>/dev/null)" || { _shellb_print_err "\"${3:-.}\" is not a valid dir" ; return 1; }
  domain_dir=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_COMMANDS}")
  _shellb_core_domain_files_ls_abs_matching_whole_line "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${user_dir}" "${command_string}" \
    && { _shellb_print_nfo "command <${command_string}> for ${user_dir} unchanged" ; return 0 ; }

  mkdir -p "${domain_dir}" || { _shellb_print_wrn "failed to create directory \"${domain_dir}\" for <${command_string}> command" ; return 1 ; }
  echo "${command_string}" > "${domain_dir}/${cmd_file}" || { _shellb_print_wrn "failed to save command <${command_string}> to \"${domain_dir}/${cmd_file}\"" ; return 1 ; }
}

# Show prompt with current command, and allow user to edit it
# command will be saved if user confirms with ENTER
# ${1} - user directory to save content for
# ${2} - content to edit (can be empty)
# ${3} - file name
# ${4} - prompt
function _shellb_command_edit() {
  _shellb_print_dbg "_shellb_command_edit($*)"
  local user_dir content file
  user_dir="${1:-.}"
  content="${2}"
  file="${3}"
  prompt="${4:-$ }"
  read -r -e -p "${prompt}" -i "${content}" content || return 1
  _shellb_command_save "${content}" "${file}" "${user_dir}"
}

# ${1} command to execute
function _shellb_command_exec() {
  _shellb_print_dbg "_shellb_command_exec($*)"
  local target="${1}"
  history -s "${target}"
  eval "${target}"
}

# Ask user to select a number from 1 to size of given array
# and execute the command from a selected command file
# ${1} - array with command files
function _shellb_command_selection_exec() {
  _shellb_print_dbg "_shellb_command_selection_exec($*)"
  local -a files
  files=("${@}")
  local index chosen_command final_command

  _shellb_print_nfo "select command to execute:"
  index=$(_shellb_core_get_user_number "${#files[@]}") || return 1
  chosen_command="$(cat "${files[${index}-1]}")"

  _shellb_print_nfo "execute command (edit & confirm with ENTER or cancel with ctrl-c):"
  read -r -e -p "$ " -i "${chosen_command}" final_command && _shellb_command_exec "${final_command}"
}

function _shellb_command_selection_del() {
  _shellb_print_dbg "_shellb_command_selection_del($*)"
  local -a files
  files=("${@}")
  local index chosen_command chosen_cmdfile chosen_tagfile

  _shellb_print_nfo "select command to delete:"
  index=$(_shellb_core_get_user_number "${#files[@]}") || return 1
  chosen_cmdfile="${files[${index}-1]}"
  chosen_tagfile="$(_shellb_command_get_tagfile_from_commandfile "${chosen_cmdfile}")"
  chosen_command="$(cat "${chosen_cmdfile}")"

  _shellb_print_nfo "command file: \"$(_shellb_command_get_resource_proto_from_abs "${chosen_cmdfile}")\""
  _shellb_core_get_user_confirmation "delete command \"${chosen_command}\"?" || return 0
  _shellb_core_remove "${chosen_cmdfile}" && _shellb_core_remove "${chosen_tagfile}" && _shellb_print_nfo "command deleted: ${chosen_command}"
}

# Ask user to select a number from 1 to size of given array
# and execute the command from a selected command file
# ${1} - array with command files
function _shellb_command_selection_edit() {
  _shellb_print_dbg "_shellb_command_selection_edit($*)"
  local -a files
  files=("${@}")
  local index command tag chosen_file user_dir user_path uuid_file

  _shellb_print_nfo "select command to edit:"
  index=$(_shellb_core_get_user_number "${#files[@]}") || return 1
  chosen_file="${files[${index}-1]}"
  command="$(cat "${chosen_file}")"

  user_path=$(_shellb_core_calc_user_from_domain "${chosen_file}" "${_SHELLB_DB_COMMANDS}")
  user_dir="$(dirname "${user_path}")"
  uuid_file="$(basename "${user_path}")"
  uuid_file="${uuid_file%.*}"
  tag="$(cat "$(dirname "${chosen_file}")/${uuid_file}.${_SHELLB_CFG_COMMAND_TAG_EXT}" 2>/dev/null)"

  _shellb_print_nfo "edit command (edit & confirm with ENTER or cancel with ctrl-c)"
  _shellb_command_edit "${user_dir}" "${command}" "${uuid_file}.${_SHELLB_CFG_COMMAND_EXT}" "$ " || { _shellb_print_err "invoke \"shellb command purge\" to remove commands saved for \"dead\" directories" ; return 1 ; }
  _shellb_print_nfo "edit tags for a command (space separated words, edit & confirm with ENTER or cancel with ctrl-c"
  _shellb_command_edit "${user_dir}" "${tag}" "${uuid_file}.${_SHELLB_CFG_COMMAND_TAG_EXT}" "#tags: " || { _shellb_print_err "invoke \"shellb command purge\" to remove commands saved for \"dead\" directories" ; return 1 ; }
}

# ${1} - directory to save command for. default is current dir
function shellb_command_save_previous() {
  local command user_dir uuid_file
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || { _shellb_print_err "\"${1:-.}\" is not a valid dir" ; return 1 ; }
  command=$(history | tail -n 2 | head -n 1 | sed 's/[0-9 ]*//')
  uuid_file="$(uuidgen -t)"
  tag="$(cat "${uuid_file}.${_SHELLB_CFG_COMMAND_TAG_EXT}" 2>/dev/null)"

  _shellb_print_nfo "save previous command for \"${user_dir}\" (edit & confirm with ENTER, cancel with ctrl-c)"
  _shellb_command_edit "${user_dir}" "${command}" "${uuid_file}.${_SHELLB_CFG_COMMAND_EXT}" "$ " || { _shellb_print_err "invoke \"shellb command purge\" to remove commands saved for \"dead\" directories" ; return 1 ; }
  _shellb_print_nfo "add optional tags for a command (space separated words, edit & confirm with ENTER or cancel with ctrl-c"
  _shellb_command_edit "${user_dir}" "${tag}" "${uuid_file}.${_SHELLB_CFG_COMMAND_TAG_EXT}" "#tags: " || { _shellb_print_err "invoke \"shellb command purge\" to remove commands saved for \"dead\" directories" ; return ; }
}

# ${1} - directory to save command for. default is current dir
function shellb_command_save_interactive() {
  local user_dir uuid_file
  user_dir="$(realpath -eq "${1:-.}" 2>/dev/null)" || { _shellb_print_err "\"${1:-.}\" is not a valid dir" ; return 1 ; }
  uuid_file="$(uuidgen -t)"

  _shellb_print_nfo "save new command for \"${user_dir}\" (edit & confirm with ENTER, cancel with ctrl-c)"
  _shellb_command_edit "${user_dir}" "" "${uuid_file}.${_SHELLB_CFG_COMMAND_EXT}" "$ " || { _shellb_print_err "invoke \"shellb command purge\" to remove commands saved for \"dead\" directories" ; return 1 ; }
  _shellb_print_nfo "add optional tags for a command (space separated words, edit & confirm with ENTER or cancel with ctrl-c"
  _shellb_command_edit "${user_dir}" "" "${uuid_file}.${_SHELLB_CFG_COMMAND_TAG_EXT}" "#tags: " || { _shellb_print_err "invoke \"shellb command purge\" to remove commands saved for \"dead\" directories" ; return 1 ; }
}

# Print out a numbered line with with command and it's tag
# ${1} - line number
# ${2} - abs command file
function _shellb_command_print_line() {
  _shellb_print_dbg "_shellb_command_print_line($*)"
  local i file tag
  i="${1}"
  file="${2}"
  [ -n "${i}" ] || { _shellb_print_err "line number not given" ; return 1 ; }
  [ -n "${file}" ] || { _shellb_print_err "command file not given" ; return 1 ; }
  tag=$(cat "$(_shellb_command_get_tagfile_from_commandfile "${file}")" 2>/dev/null)

#  if (( i % 2 == 1 )); then
#    printf "%3s) | %20s | %s\n" "${i}" "${tag}" "$(cat "${2}")" | sed -e 's@\([.]*|\)\([^|]*\)@\1\n\2@' | sed -e 's@\([^|]*\)\([.]*\)@\1\n\2@' | sed -e '3s/ /\./g ; 3s/^\./ /; 3s/\.$/ /; ' | tr -d '\n' | sed '$s/$/\n/'
#  else
#    printf "%3s) | %20s | %s\n" "${i}" "${tag}" "$(cat "${2}")" | sed -e 's@\([.]*|\)\([^|]*\)@\1\n\2@' | sed -e 's@\([^|]*\)\([.]*\)@\1\n\2@' | sed -e '3s/ /_/g ; 3s/^_/ /; 3s/_$/ /; ' | tr -d '\n' | sed '$s/$/\n/'
#  fi

  if [[ $(((i-1) % 2)) -lt 1 ]]; then
    printf "${_SHELLB_CFG_COLOR_ROW}%3s) | %20s | %s${_SHELLB_COLOR_NONE}\n" "${i}" "${tag}" "$(cat "${file}")"
  else
    printf "%3s) | %20s | %s\n" "${i}" "${tag}" "$(cat "${file}")"
  fi

}

function _shellb_command_print_lines() {
  local -n shellb_command_print_lines_files=$1
  local i=0
  for file in "${shellb_command_print_lines_files[@]}"; do
    i=$((i+1))
    _shellb_command_print_line "${i}" "${file}"
  done
}

# Generate nameref array of command files in given directory, or returns 1 if none found or given dir is invalid
# Generated paths are absolute
# $1 - user directory to list command for (default: current dir)
# $2 - nameref array variable under which shellb command will be saved
function _shellb_command_list_flat() {
  _shellb_print_dbg "_shellb_command_list_flat($*)"

  local -n shellb_command_list_flat_files=$2    2> /dev/null # ignore error if variable is not declared
  local user_dir

  # some sanity checks
  user_dir=$(realpath -qe "${1:-.}" 2>/dev/null) || { _shellb_print_err "\"${1}\" is not a valid dir" ; return 1 ; }
  [ -d "${user_dir}" ] || { _shellb_print_err "command list failed, \"${user_dir}\" is not a dir" ; return 1 ; }

  # fetch all commands under given domain dir and save them in a nameref array
  mapfile -t shellb_command_list_flat_files < <(_shellb_core_domain_files_ls_abs "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${user_dir}")

  # check if any commands were found
  [ ${#shellb_command_list_flat_files[@]} -gt 0 ] || { _shellb_print_err "no commands in \"$(_shellb_command_get_resource_proto_from_user "${user_dir}")\"" ; return 1 ; }
}

# Generate nameref array of command files below given directory, or returns 1 if none found or given dir is invalid
# Generated paths are absolute
# $1 - user directory to list command for (default: current dir)
# $2 - nameref array variable under which shellb command will be saved
function _shellb_command_list_recursive() {
  _shellb_print_dbg "_shellb_command_list_recursive($*)"

  local -n shellb_command_list_recursive_files=$2    2> /dev/null # ignore error if variable is not declared
  local user_dir

  # some sanity checks
  user_dir=$(realpath -qe "${1:-.}" 2>/dev/null) || { _shellb_print_err "\"${1}\" is not a valid dir" ; return 1 ; }
  [ -d "${user_dir}" ] || { _shellb_print_err "command list failed, \"${user_dir}\" is not a dir" ; return 1 ; }

  # fetch all commands under given domain dir and save them in a nameref array
  mapfile -t shellb_command_list_recursive_files < <(_shellb_core_domain_files_find_abs "${_SHELLB_DB_COMMANDS}" "*.${_SHELLB_CFG_COMMAND_EXT}" "${user_dir}")

  # check if any commands were found
  [ ${#shellb_command_list_recursive_files[@]} -gt 0 ] || { _shellb_print_err "no commands in \"$(_shellb_command_get_resource_proto_from_user "${user_dir}")\"" ; return 1 ; }
}

###############################################
# command functions - list
###############################################

# Lists commands in given directory, or returns 1 if none found or given dir is invalid
# $1 - user directory to list command for (default: current dir)
# $2 - optional, nameref array variable under which shellb command will be saved
# $3 - optional, nameref array variable under which commands will be saved
function shellb_command_list() {
  _shellb_print_dbg "shellb_command_list($*)"

  # shellcheck disable=SC2034
  local -n shellb_command_list_files=$1    2> /dev/null # ignore error if variable is not declared
  shift

  local tag
  [[ "${1:0:1}" = "@" ]] && { tag="${1:1}" ; shift; } || tag="${2:1}"

  local user_dir="${1:-.}"
  _shellb_command_list_flat "${user_dir}" shellb_command_list_files || return 1

  # print only commands that match the tag
  if [[ -n "${tag}" ]]; then
    local -a shellb_command_list_files_tagged
    for file in "${shellb_command_list_files[@]}"; do
      if grep -qw "${tag}" "$(_shellb_command_get_tagfile_from_commandfile "${file}")" 2>/dev/null; then
        shellb_command_list_files_tagged+=("${file}")
      fi
    done
    shellb_command_list_files=("${shellb_command_list_files_tagged[@]}")

    [ ${#shellb_command_list_files_tagged[@]} -gt 0 ] || { _shellb_print_err "no commands found with tag \"${tag}\"" ; return 1; }
    _shellb_print_nfo "commands in \"$(_shellb_command_get_resource_proto_from_user "${user_dir}")\" with tag \"${tag}\""
  else
    _shellb_print_nfo "commands in \"$(_shellb_command_get_resource_proto_from_user "${user_dir}")\""
  fi

  _shellb_command_print_lines shellb_command_list_files
}

# Open a list of commands installed for given dir, and allow user to select which one to execute
# $1 - optional directory to list command for (default: current dir)
function shellb_command_list_exec() {
  _shellb_print_dbg "shellb_command_list_exec($*)"

  # shellcheck disable=SC2034
  local -a shellb_command_list_exec_files
  # get list of commands
  shellb_command_list shellb_command_list_exec_files "$@" || return 1
  _shellb_command_selection_exec "${shellb_command_list_exec_files[@]}"
}

# Open a list of commands installed for given dir, and allow user to select one to edit
# $1 - optional directory to list command for (default: current dir)
function shellb_command_list_edit() {
  _shellb_print_dbg "shellb_command_list_edit($*)"

  # shellcheck disable=SC2034
  local -a shellb_command_list_edit_files
  # get list of commands
  shellb_command_list shellb_command_list_edit_files "$@" || return 1
  _shellb_command_selection_edit "${shellb_command_list_edit_files[@]}"
}

# Open a list of commands installed for given dir, and allow user to select one to delete
# $1 - optional directory to list command for (default: current dir)
function shellb_command_list_del() {
  _shellb_print_dbg "shellb_command_list_del($*)"

  # shellcheck disable=SC2034
  local -a shellb_command_list_del_files
  # get list of commands
  shellb_command_list shellb_command_list_del_files "$@" || return 1
  _shellb_command_selection_del "${shellb_command_list_del_files[@]}"
}

###############################################
# command functions - find
###############################################

# Lists commands below given directory; return 1 if none found or given dir is invalid
# When given a tag, only commands with that tag will be returned
# $1 - user directory to list command for (default: current dir)
function shellb_command_find() {
  _shellb_print_dbg "shellb_command_find($*)"

  # shellcheck disable=SC2034
  local -n shellb_command_find_files=$1    2> /dev/null # ignore error if variable is not declared
  shift

  local tag
  [[ "${1:0:1}" = "@" ]] && { tag="${1:1}" ; shift; } || tag="${2:1}"
  local user_dir="${1:-.}"
  _shellb_command_list_recursive "${user_dir}" shellb_command_find_files || return 1

  # print only commands that match the tag
  if [[ -n "${tag}" ]]; then
    local -a shellb_command_find_files_tagged
    for file in "${shellb_command_find_files[@]}"; do
      if grep -qw "${tag}" "$(_shellb_command_get_tagfile_from_commandfile "${file}")" 2>/dev/null; then
        shellb_command_find_files_tagged+=("${file}")
      fi
    done
    shellb_command_find_files=("${shellb_command_find_files_tagged[@]}")

    [ ${#shellb_command_find_files_tagged[@]} -gt 0 ] || { _shellb_print_err "no commands found with tag \"${tag}\"" ; return 1; }
    _shellb_print_nfo "commands below \"$(_shellb_command_get_resource_proto_from_user "${user_dir}")\" with tag \"${tag}\""
  else
    _shellb_print_nfo "commands below \"$(_shellb_command_get_resource_proto_from_user "${user_dir}")\""
  fi

  # print commands
  _shellb_command_print_lines shellb_command_find_files
}

# Show a list of commands installed below given dir, and allow user to select which one to execute
# $1 - optional directory to list command for (default: current dir)
function shellb_command_find_exec() {
  _shellb_print_dbg "shellb_command_list_exec($*)"

  # shellcheck disable=SC2034
  local shellb_command_find_exec_files

  # get list of commands
  shellb_command_find shellb_command_find_exec_files "$@"|| return 1
  _shellb_command_selection_exec "${shellb_command_find_exec_files[@]}"
}

# Show list of commands installed below given dir, and allow user to select one to edit
# $1 - optional directory to list command for (default: current dir)
function shellb_command_find_edit() {
  _shellb_print_dbg "shellb_command_find_edit($*)"

  # shellcheck disable=SC2034
  local -a shellb_command_find_edit_files
  # get list of commands
  shellb_command_find shellb_command_find_edit_files "$@" || return 1
  _shellb_command_selection_edit "${shellb_command_find_edit_files[@]}"
}

# Show list of commands installed below given dir, and allow user to select one to delete
# $1 - optional directory to list command for (default: current dir)
function shellb_command_find_del() {
  _shellb_print_dbg "shellb_command_list_del($*)"

  # shellcheck disable=SC2034
  local -a shellb_command_find_del_files
  # get list of commands
  shellb_command_find shellb_command_find_del_files "$@" || return 1
  _shellb_command_selection_del "${shellb_command_find_del_files[@]}"
}

# Scans all available command files, and checks if they are bound to a still existing
# resource. If not, the command files are deleted.
function shellb_command_purge() {
  _shellb_print_dbg "shellb_command_list_del($*)"

  local -a shellb_command_purge_files
  _shellb_command_list_recursive "/" shellb_command_purge_files || return 1

  local -a files_to_purge
  for cmd_file in "${shellb_command_purge_files[@]}"; do
    # Skip the current iteration if the user directory exists
    [ -d "$(_shellb_core_calc_user_from_domain "$(dirname "${cmd_file}")" "${_SHELLB_DB_COMMANDS}")" ] && continue

    [ ${#files_to_purge[@]} -eq 0 ] && _shellb_print_nfo "purged \"dead\" commands:"
    files_to_purge+=("${cmd_file}")
    _shellb_command_print_line "${#files_to_purge[@]}" "${cmd_file}"
  done

  [ ${#files_to_purge[@]} -eq 0 ] && { _shellb_print_nfo "no commands purged (all commands were \"alive\")" ; return 0; }

  _shellb_core_get_user_confirmation "delete ${#files_to_purge[@]} commands saved for inaccessible dirs?" || return 0
  for cmd_file in "${files_to_purge[@]}"; do
    local tag_file
    tag_file=$(_shellb_command_get_tagfile_from_commandfile "${cmd_file}")
    _shellb_core_remove "${tag_file}" 2> /dev/null # this can fail, ignore errors
    _shellb_core_remove "${cmd_file}" || { _shellb_print_err "failed to remove command file \"${cmd_file}\"" ; return 1; }
  done
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
  [ -n "${action}" ] || { _shellb_print_err "no action given" ; return 1; }

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
        -c|--current)
          shellb_command_list_edit "$@"
          ;;
        -r|--recursive)
          shellb_command_find_edit "$@"
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
        -c|--current)
          shellb_command_list "" "$@"
          ;;
        -r|--recursive)
          shellb_command_find "" "$@"
          ;;
        *)
          _shellb_print_err "unknown scope \"${arg}\" passed to \"command $action\""
          return 1
          ;;
      esac
      ;;
    purge)
      shellb_command_purge "$@"
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
          opts="--current --recursive -c -r"
          ;;
        run)
          opts="--current --recursive -c -r"
          ;;
        edit)
          opts="--current --recursive -c -r"
          ;;
        list)
          opts="--current --recursive -c -r"
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
      action="${COMP_WORDS[2]}"
      arg="${COMP_WORDS[3]}"
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
          _shellb_print_wrn "unknown command \"${comp_cur}\", words=${COMP_WORDS[*]}"
          opts=""
          ;;
      esac
      ;;
  esac

  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
}