
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

echo "note extension loading..."


if [[ -n "${SHELB_DEVEL_DIR}" ]]; then
  # shellcheck source=core.sh
  source core.sh
fi

_SHELLB_DB_NOTES="${_SHELLB_DB}/notes"
[ ! -e "${_SHELLB_DB_NOTES}" ] && mkdir -p "${_SHELLB_DB_NOTES}"

###############################################
# notepad functions
###############################################
# ${1} - optional directory to calculate abs dir for
function _shellb_notepad_calc_absdir() {
  _shellb_print_dbg "_shellb_notepad_calc_absdir($*)"
  _shellb_core_calc_absdir "${_SHELLB_DB_NOTES}" "${1}"
}

# ${1} - optional directory to calculate abs file for
function _shellb_notepad_calc_absfile() {
  _shellb_print_dbg "_shellb_notepad_calc_absfile($*)"
  _shellb_core_calc_absfile "${_SHELLB_CFG_NOTE_FILE}" "${_SHELLB_DB_NOTES}" "${1}"
}

# ${1} - optional directory to calculate notepad domain file for
function _shellb_notepad_calc_domainfile() {
  _shellb_print_dbg "_shellb_notepad_calc_domainfile($*)"
  local notepad_absfile
  notepad_absfile="$(_shellb_notepad_calc_absfile "${1}")"
  echo "${_SHELLB_CFG_PROTO}$(_shellb_core_calc_domainfile "${notepad_absfile}" "${_SHELLB_DB_NOTES}")"
}

# ${1} - optional directory to calculate notepad domain dir for
function _shellb_notepad_calc_domaindir() {
  _shellb_print_dbg "_shellb_notepad_calc_domaindir($*)"
  local notepad_absdir
  notepad_absdir="$(_shellb_notepad_calc_absdir "${1}")"
  echo "${_SHELLB_CFG_PROTO}$(_shellb_core_calc_domainfile "${notepad_absdir}" "${_SHELLB_DB_NOTES}")"
}

# displays path to notepad file for given or current directory
# will fail if no notepad is created yet
function shellb_notepad_get_absfile() {
  _shellb_print_dbg "shellb_notepad_get_absfile()"
  local notepad_absfile
  notepad_absfile="$(_shellb_notepad_calc_absfile "${1}")"
  [ -e "${notepad_absfile}" ] || _shellb_print_err "notepad get failed, no \"${1:-.}\" notepad" || return 1
  echo "${notepad_absfile}"
}

# opens a notepad for current directory in
function shellb_notepad_edit() {
  _shellb_print_dbg "shellb_notepad_edit($*)"
  mkdir -p "$(_shellb_notepad_calc_absdir "${1}")" || _shellb_print_err "notepad edit failed, is ${_SHELLB_DB_NOTES} accessible?" || return 1
  "${shellb_cfg_notepad_editor}" "$(_shellb_notepad_calc_absfile "${1}")"
}

function shellb_notepad_show() {
  _shellb_print_dbg "shellb_notepad_show($*)"
  local user_dir notepad_absfile notepad_domainfile

  user_dir="${1:-.}"
  notepad_absfile="$(_shellb_notepad_calc_absfile "${user_dir}")"
  notepad_domainfile="$(_shellb_notepad_calc_domainfile "${user_dir}")"

  [ -e "${notepad_absfile}" ] || _shellb_print_err "notepad show failed, no \"${notepad_domainfile}\" notepad / ${notepad_absfile}" || return 1
  [ -s "${notepad_absfile}" ] || _shellb_print_wrn_fail "notepad show: notepad \"${notepad_domainfile}\" is empty" || return 1
  _shellb_print_wrn "$(printf '%s' "---- ${notepad_domainfile}") $(printf '%*.*s' 0 $((_SHELLB_CFG_NOTEPAD_TITLE_W - ${#notepad_domainfile} - 5)) "${_SHELLB_CFG_SEPARATOR}")"
  cat "${notepad_absfile}" || _shellb_print_err "notepad show failed, is ${_SHELLB_DB_NOTES }accessible?" || return 1
}

function shellb_notepad_show_recurse() {
  _shellb_print_dbg "shellb_notepad_show_recurse($*)"

  local notepads_column notepads_path
  notepads_path="${1:-.}"
  notepads_column="$(_shellb_notepad_list_row "${notepads_path}")"
  for notepad in ${notepads_column}; do
    shellb_notepad_show "$(dirname "${notepads_path}/${notepad}")"
  done
}

function _shellb_notepad_list_column() {
  _shellb_core_find_as_column "${_SHELLB_DB_NOTES}" "${_SHELLB_CFG_NOTE_FILE}" "${1}"
}

function _shellb_notepad_list_row() {
  _shellb_core_find_as_row "${_SHELLB_DB_NOTES}" "${_SHELLB_CFG_NOTE_FILE}" "${1}"  && echo ""
}

function shellb_notepad_del() {
  _shellb_print_dbg "shellb_notepad_del($*)"

  local notepad_absfile notepad_domainfile
  notepad_absfile="$(_shellb_notepad_calc_absfile "${1:-.}")"
  notepad_domainfile="$(_shellb_notepad_calc_domainfile "${1:-.}")"

  [ -e "${notepad_absfile}" ] || _shellb_print_err "notepad del failed, no \"${notepad_domainfile}\" notepad" || return 1
  _shellb_core_get_user_confirmation "delete \"${_SHELLB_CFG_PROTO}${notepad_domainfile}\" notepad?" || return 0
  rm "${notepad_absfile}" || _shellb_print_err "notepad \"${notepad_domainfile}\" del failed, is it accessible?" || return 1
  _shellb_print_nfo "\"${notepad_domainfile}\" notepade deleted"
}

function shellb_notepad_delall() {
  _shellb_print_dbg "shellb_notepad_delall($*)"
  _shellb_core_get_user_confirmation "delete all notepads?" || return 0 && _shellb_print_nfo "deleting all notepads"

  rm "${_SHELLB_DB_NOTES:?}"/* -rf
  _shellb_print_nfo "all notepads deleted"
}

function _shellb_notepad_list_print_menu() {
  local notepads_seen i=1
  notepads_seen=0
  while read -r notepadfile
  do
    notepads_seen=1
    # display only the part of the path that is not the notepad directory
    printf "%3s) %s\n" "${i}" "${notepadfile}"
    i=$(($i+1))
  done < <(_shellb_notepad_list_column "${1:-.}") || return 1

  # if no notepads seen, return error
  [ "${notepads_seen}" -eq 1 ] || return 1
}

function shellb_notepad_list() {
  _shellb_print_dbg "shellb_notepad_list($*)"
  local notepads_list user_dir notepad_domaindir

  user_dir="${1:-.}"
  notepad_domaindir="$(_shellb_notepad_calc_domaindir "${user_dir}")"

  notepads_list=$(_shellb_notepad_list_print_menu "${user_dir}") || _shellb_print_err "notepad list failed, no notepads below \"${notepad_domaindir}\"" || return 1
  if [ "${user_dir}" = "/" ]; then
    _shellb_print_nfo "all notepads (below \"/\"):"
  else
    _shellb_print_nfo "notepads below \"${notepad_domaindir}\":"
  fi
  echo "${notepads_list}"
}

# TODO add to shotrcuts/config
function shellb_notepad_list_edit() {
  _shellb_print_dbg "shellb_notepad_list_edit($*)"
  local notepads_list target user_dir
  user_dir="${1:-.}"

  notepads_list=$(shellb_notepad_list "${user_dir}") || return 1
  echo "${notepads_list}"
  _shellb_print_nfo "select notepad to edit:"

  # ask user to select a notepad, but omit the first line (header)
  # from a list that will be parsed by _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_column "$(echo "${notepads_list}" | tail -n +2)" "2")
  shellb_notepad_edit "${user_dir}/$(dirname "${target}")"
}

# TODO add to shotrcuts/config
function shellb_notepad_list_show() {
  _shellb_print_dbg "shellb_notepad_list_show($*)"
  local notepads_list target user_dir
  user_dir="${1:-.}"

  notepads_list=$(shellb_notepad_list "${user_dir}") || return 1
  echo "${notepads_list}"
  _shellb_print_nfo "select notepad to show:"

  # ask user to select a notepad, but omit the first line (header)
  # from a list that will be parsed by _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_column "$(echo "${notepads_list}" | tail -n +2)" "2")
  shellb_notepad_show "${user_dir}/$(dirname "${target}")"
}

# TODO add to shotrcuts/config
function shellb_notepad_list_del() {
  _shellb_print_dbg "shellb_notepad_list_del($*)"
  local notepads_list target user_dir
  user_dir="${1:-.}"

  notepads_list=$(shellb_notepad_list "${user_dir}") || return 1
  echo "${notepads_list}"
  _shellb_print_nfo "select notepad to delete:"

  # ask user to select a notepad, but omit the first line (header)
  # from a list that will be parsed by _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_column "$(echo "${notepads_list}" | tail -n +2)" "2")
  shellb_notepad_del "${user_dir}/$(dirname "${target}")"
}








function _shellb_note_action() {
  _shellb_print_dbg "_shellb_note_action($*)"
  local action
  action=$1
  [ -n "${action}" ] || _shellb_print_err "no action given" || return 1

  case ${action} in
    edit)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    editlocal)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    del)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    dellocal)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    cat)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    catlocal)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    list)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    listlocal)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    purge)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    *)
      _shellb_print_err "unknown action \"note $action\""
      ;;
  esac
}

function _shellb_note_completion_opts() {
  _shellb_print_dbg "_shellb_note_completion_opts($*)"

  local comp_words comp_cword comp_cur comp_prev opts
  comp_cword=$1
  shift
  comp_words=( $@ )
  comp_cur="${comp_words[$comp_cword]}"
  comp_prev="${comp_words[$comp_cword-1]}"

  case ${comp_cword} in
    1)
      opts="edit editlocal del dellocal cat catlocal list listlocal purge"
      ;;
    2)
      case "${comp_prev}" in
        edit|editlocal|del|dellocal|cat|catlocal|list|listlocal|purge)
          opts="SOME_OPTS"
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