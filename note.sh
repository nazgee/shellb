
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

_SHELLB_DB_NOTES="${_SHELLB_DB}/notes"
[ ! -e "${_SHELLB_DB_NOTES}" ] && mkdir -p "${_SHELLB_DB_NOTES}"

###############################################
# notepad functions
###############################################

# opens a notepad for current directory in
function shellb_notepad_edit() {
  _shellb_print_dbg "shellb_notepad_edit($*)"

  local target proto_target selection
  selection="$(realpath -mq "${1:-./${_SHELLB_CFG_NOTE_FILE}}" 2>/dev/null)"
  [ -d "${selection}" ] && selection="${selection}/${_SHELLB_CFG_NOTE_FILE}"
  target=$(_shellb_core_calc_domain_from_user "${selection}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_domainrel_from_abs "${target}" "${_SHELLB_DB_NOTES}")

  mkdir -p "$(dirname "${target}")" || _shellb_print_err "notepad edit failed, is ${_SHELLB_DB_NOTES} accessible?" || return 1
  eval "${shellb_notepad_editor}" "${target}"
  _shellb_print_nfo "\"${proto_target}\" notepad edited"
}

function shellb_notepad_show() {
  _shellb_print_dbg "shellb_notepad_show($*)"
  local user_dir notepad_absfile notepad_domainfile

  local target proto_target selection
  selection="$(realpath -mq "${1:-./${_SHELLB_CFG_NOTE_FILE}}" 2>/dev/null)"
  [ -d "${selection}" ] && selection="${selection}/${_SHELLB_CFG_NOTE_FILE}"
  target=$(_shellb_core_calc_domain_from_user "${selection}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_domainrel_from_abs "${target}" "${_SHELLB_DB_NOTES}")

  [ -e "${target}" ] || _shellb_print_err "notepad cat failed, no \"${proto_target}\" notepad" || return 1
  [ -s "${target}" ] || _shellb_print_err "notepad cat failed, \"${proto_target}\" is empty" || return 1
  cat "${target}"
}

# $1 - notepad file to delete (in user domain)
function shellb_notepad_del() {
  _shellb_print_dbg "shellb_notepad_del($*)"

  local target proto_target selection
  selection="$(realpath -mq "${1:-./${_SHELLB_CFG_NOTE_FILE}}" 2>/dev/null)"
  [ -d "${selection}" ] && selection="${selection}/${_SHELLB_CFG_NOTE_FILE}"
  target=$(_shellb_core_calc_domain_from_user "${selection}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_domainrel_from_abs "${target}" "${_SHELLB_DB_NOTES}")

  [ -f "${target}" ] || _shellb_print_err "notepad del failed, no \"${target}\" notepad" || return 1
  _shellb_core_get_user_confirmation "delete \"${proto_target}\" notepad?" || return 0
  _shellb_core_remove "${target}" || _shellb_print_err "notepad \"${notepad_domainfile}\" del failed, is it accessible?" || return 1
  _shellb_print_nfo "\"${proto_target}\" notepad deleted"
}

function shellb_notepad_delall() {
  _shellb_print_dbg "shellb_notepad_delall($*)"
  _shellb_core_get_user_confirmation "delete all notepads?" || return 0 && _shellb_print_nfo "deleting all notepads"

  # delete all notepads. this is a bit dangerous, but we have a confirmation step above
  # in case _SHELLB_DB_NOTES is not set, script should exit becase :? will fail
  _shellb_core_remove_dir "${_SHELLB_DB_NOTES}" || _shellb_print_err "notepad delall failed, is ${_SHELLB_DB_NOTES} accessible?" || return 1
  _shellb_print_nfo "all notepads deleted"
}

# Prints a menu of notepads below given directory, or returns 1 if none found or given dir is invalid
# $1 - optional directory to list notepads for (default: current dir)
function _shellb_notepad_list_print_menu() {
  _shellb_print_dbg "_shellb_notepad_list_print_menu($*)"
  local user_dir i=0
  user_dir=$(realpath -qe "${1:-.}" 2>/dev/null) || return 1
  # fetch all notes under given domain dir
  mapfile -t matched_notes < <(_shellb_core_domain_files_find "${_SHELLB_DB_NOTES}" "*" "${user_dir}")
  # check if any notes were found
  [ ${#matched_notes[@]} -gt 0 ] || return 1

  # print note files
  for note in "${matched_notes[@]}"; do
    i=$((i+1))
    printf "%3s) | %s\n" "${i}" "${note}"
  done
}

# Lists notes below given directory, or returns 1 if none found or given dir is invalid
# $1 - optional directory to list notes below (default: /, will find all notes)
function shellb_notepad_list() {
  _shellb_print_dbg "shellb_notepad_list($*)"

  local target proto_target user_dir
  user_dir=$(realpath -qe "${1:-/}" 2>/dev/null) || _shellb_print_err "notepad list failed, \"${1}\" is not a valid dir" || return 1
  [ -d "${user_dir}" ] || _shellb_print_err "notepad list failed, \"${user_dir}\" is not a dir" || return 1
  target=$(_shellb_core_calc_domain_from_user "${user_dir}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_domainrel_from_abs "${target}" "${_SHELLB_DB_NOTES}")

  notepads_list=$(_shellb_notepad_list_print_menu "${user_dir}") || _shellb_print_err "notepad list failed, no notepads below \"${proto_target}\"" || return 1
  if [ "${user_dir}" = "/" ]; then
    _shellb_print_nfo "all notepads in ${proto_target}"
  else
    _shellb_print_nfo "notepads below \"${proto_target}\""
  fi
  echo "${notepads_list}"
}

function shellb_notepad_list_edit() {
  _shellb_print_dbg "shellb_notepad_list_edit($*)"
  local list target selection user_dir notes_count
  user_dir="${1:-./${_SHELLB_CFG_NOTE_FILE}}"

  if [ -d "${user_dir}" ]; then
    list=$(shellb_notepad_list "${user_dir}") || return 1
    echo "${list}"
    notes_count=$(($(echo "${list}" | wc -l) - 1))
    if [ "${notes_count}" -gt 2 ]; then
      _shellb_print_nfo "select notepad to edit:"
      selection=$(_shellb_core_get_user_number "${notes_count}") || return 1
    else
      selection=1
    fi
    target="${user_dir}/$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 2)"
  else
    target="${user_dir}"
  fi
  shellb_notepad_edit "${target}"
}

function shellb_notepad_list_show() {
  _shellb_print_dbg "shellb_notepad_list_show($*)"
  local list target selection user_dir notes_count
  user_dir=$(realpath -qm "${1:-/}" 2>/dev/null) || return 1

  if [ -d "${user_dir}" ]; then
    list=$(shellb_notepad_list "${user_dir}") || return 1
    echo "${list}"
    notes_count=$(($(echo "${list}" | wc -l) - 1))
    _shellb_print_nfo "select notepad to show:"
    selection=$(_shellb_core_get_user_number "${notes_count}") || return 1
    target="${user_dir}/$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 2)"
  else
    target="${user_dir}"
  fi
  shellb_notepad_show "${target}"
}

# $1 - notepad or direcotry to delete. If it's a directory, ask user to select a notepad
function shellb_notepad_list_del() {
  _shellb_print_dbg "shellb_notepad_list_del($*)"
  local list target selection user_dir notes_count
  user_dir="${1:-/}"

  if [ -d "${user_dir}" ]; then
    list=$(shellb_notepad_list "${user_dir}") || return 1
    echo "${list}"
    notes_count=$(($(echo "${list}" | wc -l) - 1))
    _shellb_print_nfo "select notepad to delete:"
    selection=$(_shellb_core_get_user_number "${notes_count}") || return 1
    target="${user_dir}/$(echo "${list}" | _shellb_core_filter_row $((selection+1)) | _shellb_core_filter_column 2)"
  else
    target="${user_dir}"
  fi
  shellb_notepad_del "${target}"
}

_SHELLB_NOTE_ACTIONS="edit del cat list purge"

function _shellb_note_action() {
  _shellb_print_dbg "_shellb_note_action($*)"
  local action
  action=$1
  shift
  [ -n "${action}" ] || _shellb_print_err "no action given" || return 1

  case ${action} in
    help)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    edit)
      shellb_notepad_list_edit "$@"
      ;;
    del)
      shellb_notepad_list_del "$@"
      ;;
    cat)
      shellb_notepad_list_show "$@"
      ;;
    list)
      shellb_notepad_list "$@"
      ;;
    purge)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    *)
      _shellb_print_err "unknown action \"note $action\""
      ;;
  esac
}

function _shellb_notepad_edit_compgen() {
  _shellb_core_compgen "${_SHELLB_DB_NOTES}" "*" "${_SHELLB_CFG_NOTE_FILE}"
}

function _shellb_notepad_delete_compgen() {
  _shellb_core_compgen "${_SHELLB_DB_NOTES}" "*" ""
}

function _shellb_notepad_cat_compgen() {
  _shellb_core_compgen "${_SHELLB_DB_NOTES}" "*" ""
}

function _shellb_notepad_list_compgen() {
  _shellb_core_compgen "${_SHELLB_DB_NOTES}" "" "" "/"
}

function _shellb_note_compgen() {
  _shellb_print_dbg "_shellb_note_compgen($*)"

  local comp_cur comp_prev opts
  comp_cur="${COMP_WORDS[COMP_CWORD]}"
  comp_prev="${COMP_WORDS[COMP_CWORD-1]}"

  _shellb_print_dbg "comp_cur: \"${comp_cur}\" COMP_CWORD: \"${COMP_CWORD}\""
  shift
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()

  case $((COMP_CWORD)) in
    2)
      opts="${_SHELLB_NOTE_ACTIONS} help"
      ;;
    3)
      case "${comp_prev}" in
        help)
          opts=${_SHELLB_NOTE_ACTIONS}
          ;;
        edit)
          _shellb_notepad_edit_compgen
          return
          ;;
        del)
          _shellb_notepad_delete_compgen
          return
          ;;
        cat)
          _shellb_notepad_cat_compgen
          return
          ;;
        list)
          _shellb_notepad_list_compgen
          return
          ;;
        purge)
          opts="aaaaaaaaaa"
          ;;
        *)
          _shellb_print_wrn "unknown command \"${comp_cur}\""
          opts=""
          ;;
      esac
      ;;
  esac

  compopt +o nospace
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
}
