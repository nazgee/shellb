
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
# ${2} - optional directory filename
function _shellb_notepad_calc_absfile() {
  _shellb_print_dbg "_shellb_notepad_calc_absfile($*)"
  _shellb_core_calc_absfile "${2:-${_SHELLB_CFG_NOTE_FILE}}" "${_SHELLB_DB_NOTES}" "${1:-.}"
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

  user_dir="${1:-/}"
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
  local list target user_dir
  user_dir="${1:-/}"

  list=$(shellb_notepad_list "${user_dir}") || return 1
  echo "${list}"
  _shellb_print_nfo "select notepad to edit:"

  # ask user to select a notepad, but omit the first line (header)
  # from a list that will be parsed by _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_column "$(echo "${list}" | tail -n +2)" "2")
  shellb_notepad_edit "${user_dir}/$(dirname "${target}")"
}

# TODO add to shotrcuts/config
function shellb_notepad_list_show() {
  _shellb_print_dbg "shellb_notepad_list_show($*)"
  local list target user_dir
  user_dir="${1:-/}"

  list=$(shellb_notepad_list "${user_dir}") || return 1
  echo "${list}"
  _shellb_print_nfo "select notepad to show:"

  # ask user to select a notepad, but omit the first line (header)
  # from a list that will be parsed by _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_column "$(echo "${list}" | tail -n +2)" "2")
  shellb_notepad_show "${user_dir}/$(dirname "${target}")"
}

# TODO add to shotrcuts/config
function shellb_notepad_list_del() {
  _shellb_print_dbg "shellb_notepad_list_del($*)"
  local list target user_dir
  user_dir="${1:-/}"

  list=$(shellb_notepad_list "${user_dir}") || return 1
  echo "${list}"
  _shellb_print_nfo "select notepad to delete:"

  # ask user to select a notepad, but omit the first line (header)
  # from a list that will be parsed by _shellb_core_get_user_selection
  target=$(_shellb_core_get_user_selection_column "$(echo "${list}" | tail -n +2)" "2")
  shellb_notepad_del "${user_dir}/$(dirname "${target}")"
}

function shellb_notepad_foo() {
  _shellb_print_nfo "foo($*)"
}


function _shellb_notepad_completion_to_dir() {
  local completion
  completion="${1}"
  [ -d "${completion}" ] && echo "${completion}" && return 0
  dirname "${completion}"
}

# Generate mixture of user-directories and shellb-resources for completion
# All user directories will be completed, but only existing shellb resource-files will be shown
# e.g. for "../" completion:
#    ../zzzzzz/    ../foo.md
#    ../bar.md     ../dirb/
# it will generate a list of user directories, as well as existing shellb resources.
# - existing user dirs:         "../zzzzzzz/" "../dirb/"
# - existing shellb resources:  "../bar.md"   "../foo.md"
#
# When non-empty $1 will be provided, non-exisiting shelb resource will be listed
# under the directory of a currently shown completion, with a name given by $1
# e.g. for "../" completion and $1="aaaaaaaaaa.md":
#    ../zzzzzz/    ../foo.md     ../aaaaaaaaaa.md
#    ../bar.md     ../dirb/
# - existing user dirs:         "../zzzzzzz/" "../dirb/"
# - existing shellb resources:  "../bar.md"   "../foo.md"
# - non-existing shellb resource: "../aaaaaaaaaa.md"
#
# $1 - optional, name of a non-existing shellb resource
# $2 - current completeion word, typ
function _shellb_notepad_comgen() {
  _shellb_print_dbg "_shellb_notepad_completion_opts_edit($*)"

  local extra_file comp_words comp_cword comp_cur comp_cur_dir comp_prev opts opts_dirs note_default note_others
  extra_file="${1}"
  comp_cword="${COMP_CWORD}"
  comp_words=( ${COMP_WORDS[@]} )
  comp_cur="${comp_words[$comp_cword]}"
  comp_prev="${comp_words[$comp_cword-1]}"

  if [ -n "${extra_file}" ]; then
    if realpath -eq "${cur:-./}" > /dev/null ; then
      # remove potential double slashes
      note_default="$(echo "${cur:-./}/${extra_file}" | tr -s /)"
    else
      note_default="$(dirname "${cur:-./}")/${extra_file}"
    fi
  fi

  # get all directories and files in direcotry of current word
  opts_dirs=$(compgen -d -S '/' -- "${cur:-.}")

  # translate current completion to a directory
  comp_cur_dir=$(_shellb_notepad_completion_to_dir "${comp_cur}")

  # check what files are in _SHELLB_DB_NOTES for current completion word
  # and for all dir-based completions
  for dir in ${opts_dirs} ${comp_cur_dir} ; do
    files_in_domain_dir=$(_shellb_core_domain_files_ls "${_SHELLB_DB_NOTES}" "*" "$(realpath "${dir}")" 2>/dev/null)
    for file_in_domain_dir in ${files_in_domain_dir} ; do
      note_others="${note_others} $(echo "${dir}/${file_in_domain_dir}" | tr -s /)"
    done
  done

  opts="${opts_dirs} ${note_default} ${note_others}"

  # we want no space added after file/dir completion
  compopt -o nospace
  COMPREPLY=( $(compgen -o nospace -W "${opts}" -- ${cur}) )
}


_SHELLB_NOTE_ACTIONS="edit editlocal del dellocal cat catlocal list listlocal purge"

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
    editlocal)
      shellb_notepad_edit "."
      ;;
    del)
      shellb_notepad_list_del "$@"
      ;;
    dellocal)
      shellb_notepad_del "."
      ;;
    cat)
      shellb_notepad_list_show "$@"
      ;;
    catlocal)
      shellb_notepad_show "."
      ;;
    foo)
      shellb_notepad_foo "$@"
      ;;
    list)
      shellb_notepad_list "$@"
      ;;
    listlocal)
      shellb_notepad_list "."
      ;;
    purge)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    *)
      _shellb_print_err "unknown action \"note $action\""
      ;;
  esac
}

function _shellb_note_compgen() {
  _shellb_print_dbg "_shellb_note_compgen($*)"

  local comp_cur comp_prev opts idx_offset
  idx_offset=1
  comp_cur="${COMP_WORDS[COMP_CWORD]}"
  comp_prev="${COMP_WORDS[COMP_CWORD-1]}"

  _shellb_print_dbg "comp_cur: \"${comp_cur}\" COMP_CWORD: \"${COMP_CWORD}\""
  shift
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()

  case $((COMP_CWORD-idx_offset)) in
    1)
      opts="${_SHELLB_NOTE_ACTIONS} help foo"
      ;;
    2)
      case "${comp_prev}" in
        help)
          opts=${_SHELLB_NOTE_ACTIONS}
          ;;
        edit)
          opts="./ $(_shellb_core_domain_files_find "${_SHELLB_DB_NOTES}" "*" "/")"
          opts="foo bar baz"
          ;;
        editlocal)
          opts="./${_SHELLB_CFG_NOTE_FILE}"
          ;;
        del)
          opts="./${_SHELLB_CFG_NOTE_FILE} $(_shellb_core_domain_files_find "${_SHELLB_DB_NOTES}" "*" "/")"
          ;;
        dellocal)
          opts="./${_SHELLB_CFG_NOTE_FILE}"
          ;;
        cat)
          opts="./${_SHELLB_CFG_NOTE_FILE} $(_shellb_core_domain_files_find "${_SHELLB_DB_NOTES}" "*" "/")"
          ;;
        catlocal)
          opts="./${_SHELLB_CFG_NOTE_FILE}"
          ;;
        list)
          opts="/ $(_shellb_core_domain_files_find "${_SHELLB_DB_NOTES}" "*" "/" | xargs -I{} dirname {})"
          ;;
        listlocal)
          opts="."
          ;;
        foo)
          _shellb_notepad_comgen "${_SHELLB_CFG_NOTE_FILE}"
          return
          ;;
        purge)
          opts=". / $(_shellb_core_domain_files_find "${_SHELLB_DB_NOTES}" "*" "/")"
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