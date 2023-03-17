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

_SHELLB_DB_BOOKMARKS="${_SHELLB_DB}/bookmarks"
[ ! -e "${_SHELLB_DB_BOOKMARKS}" ] && mkdir -p "${_SHELLB_DB_BOOKMARKS}"

###############################################
# bookmark functions
###############################################
function _shellb_bookmarks_calc_absfile() {
  _shellb_core_calc_domain_from_user "/${1}" "${_SHELLB_DB_BOOKMARKS}"
}

function _shellb_bookmark_glob() {
  _shellb_core_domain_files_ls "${_SHELLB_DB_BOOKMARKS}" "${1}" "/"
}

function _shellb_bookmark_get() {
  _shellb_print_dbg "_shellb_bookmark_get(${1})"
  # check if bookmark name is given
  [ -n "${1}" ] || return 1
  cat "$(_shellb_bookmarks_calc_absfile "${1}")" 2> /dev/null
}

function _shellb_bookmark_is_alive() {
  _shellb_print_dbg "_shellb_bookmark_is_alive(${1})"
  # check if bookmark name is given
  [ -n "${1}" ] || return 1
  [ -d "$(_shellb_bookmark_get "${1}")" ]
}

function _shellb_bookmark_print_long() {
  # check if target is "alive" or "dangling"
  if _shellb_bookmark_is_alive "$1"; then
    printf "${_SHELLB_CFG_SYMBOL_CHECK} | %-18s | %s\n" "${1}" "${2}"
  else
    printf "${_SHELLB_CFG_SYMBOL_CROSS} | %-18s | ${_SHELLB_CFG_COLOR_ERR}%s${_SHELLB_COLOR_NONE}\n" "${1}" "${2}"
  fi
}

function shellb_bookmark_set() {
  _shellb_print_dbg "_shellb_bookmark_set(${1}, ${2})"
  local bookmark_target bookmark_name bookmark_file
  bookmark_name="${1}"

  # check if bookmark name is given
  [ -n "${bookmark_name}" ] || _shellb_print_err "set bookmark failed, no bookmark name given" || return 1

  # if second arg is not given, bookmark current directory
  bookmark_target="${2:-$(pwd)}"

  # translate relative paths to absolute paths
  bookmark_target=$(realpath "${bookmark_target}")

  # sanity check if bookmark directory exists
  [ -e "${bookmark_target}" ] || _shellb_print_err "set bookmark failed, invalid directory (${bookmark_target})" || return 1

  # check if we already have a bookmark with this name
  bookmark_file="$(_shellb_bookmarks_calc_absfile "${bookmark_name}")"
  if [ -e "${bookmark_file}" ]; then
    # check if the bookmark is the same as the one we want to set
    if (_shellb_core_is_same_as_file "${bookmark_target}" "${bookmark_file}"); then
      :
    else
      _shellb_core_get_user_confirmation "bookmark \"${bookmark_name}\" to \"$(_shellb_bookmark_get "${bookmark_name}")\" exists, overwrite?" || return 0
    fi
  fi

  # build the bookmark file with the contents "$CD directory_path"
  echo "${bookmark_target}" > "${bookmark_file}" || _shellb_print_err "set bookmark failed, saving bookmark failed" || return 1

  _shellb_print_nfo "bookmark set:"
  shellb_bookmark_get_long "${1}"
}

# $1 name of bookmark to delete
# $2 if given, don't ask for confirmation
function shellb_bookmark_del() {
  local bookmark_name assume_yes
  bookmark_name="${1}"
  assume_yes="${2}"

  _shellb_print_dbg "shellb_bookmark_del(${1})"
  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "del bookmark failed, no bookmark name given" || return 1
  [ -e "$(_shellb_bookmarks_calc_absfile "${1}")" ] || _shellb_print_err "del bookmark failed, unknown bookmark: \"${1}\"" || return 1
  [ -n "${assume_yes}" ] || _shellb_core_get_user_confirmation "delete \"${1}\" bookmark?" || return 0
  rm "$(_shellb_bookmarks_calc_absfile "${1}")" 2>/dev/null || _shellb_print_err "del bookmark failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1
  _shellb_print_nfo "bookmark deleted: ${1}"
}

function shellb_bookmark_get_short() {
  _shellb_print_dbg "shellb_bookmark_get_short(${1})"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "get bookmark failed, no bookmark name given" || return 1
  # print the bookmark name or display an error message
  _shellb_bookmark_get "${1}" || _shellb_print_err "get bookmark failed, unknown bookmark" || return 1
}

function shellb_bookmark_get_long() {
  _shellb_print_dbg "shellb_bookmark_get_long(${1})"

  # check if bookmark is known, and save it in target
  local target
  target=$(shellb_bookmark_get_short "$1") || return 1 # error message already printed
  _shellb_bookmark_print_long "${1}" "${target}"
}

function shellb_bookmark_goto() {
  _shellb_print_dbg "shellb_bookmark_goto(${1})"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "goto bookmark failed, no bookmark name given" || return 1

  # check if given bookmark exists
  [ -e "$(_shellb_bookmarks_calc_absfile "${1}")" ] || _shellb_print_err "goto bookmark failed, unknown bookmark: \"${1}\"" || return 1

  # get bookmarked directory
  local target
  target=$(_shellb_bookmark_get "${1}") || _shellb_print_err "goto bookmark failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1

  # go to bookmarked directory
  cd "${target}" || _shellb_print_err "goto bookmark failed, bookmark to dangling directory or no permissions to enter it" || return 1
}

function shellb_bookmark_list_long() {
  _shellb_print_dbg "shellb_bookmark_list_long($*)"

  # fetch all bookmarks or only those starting with given glob expression
  mapfile -t matched_bookmarks < <(_shellb_bookmark_glob "${1}")
  # check any bookmarks were found
  [ ${#matched_bookmarks[@]} -gt 0 ] || _shellb_print_wrn_fail "no bookmarks matching \"${1}\" glob expression" || return 1

  # print the bookmarks
  local i=1
  for bookmark in "${matched_bookmarks[@]}"; do
    printf "%3s) | " "${i}"
    shellb_bookmark_get_long "${bookmark}"
    i=$((i+1))
  done
}

function shellb_bookmark_list_short() {
  _shellb_print_dbg "shellb_bookmark_list_short($*)"

  # fetch all bookmarks or only those starting with given glob expression
  mapfile -t matched_bookmarks < <(_shellb_bookmark_glob "${1}")
  # check any bookmarks were found
  [ ${#matched_bookmarks[@]} -gt 0 ] || _shellb_print_wrn_fail "no bookmarks matching \"${1}\" glob expression" || return 1
  # print the bookmarks
  echo "${matched_bookmarks[@]}"
}

function shellb_bookmark_list_goto() {
  local list selection target
  # if no bookmarks matched -- exit immediatly
  list=$(shellb_bookmark_list_long "${1}")  || return 1

  # if we have some bookmarks, let user choose
  if [[ $(echo "${list}" | wc -l) -gt 1 ]]; then
    echo "$list"
    _shellb_print_nfo "select bookmark to goto:"
    read -r selection || return 1
  else
    selection="1"
  fi
  target=$(echo "${list}" | _shellb_core_filter_row "${selection}" | _shellb_core_filter_column "3")

  shellb_bookmark_goto "$(_shellb_core_string_trim "${target}")"
}

function shellb_bookmark_list_del() {
  local list target
  # if no bookmarks matched -- exit immediatly
  list=$(shellb_bookmark_list_long "${1}")  || return 1

  # if we have some bookmarks, let user choose
  if [[ $(echo "${list}" | wc -l) -gt 1 ]]; then
    echo "$list"
    _shellb_print_nfo "select bookmark to delete:"
    read -r selection || return 1
  else
    selection="1"
  fi
  target=$(echo "${list}" | _shellb_core_filter_row "${selection}" | _shellb_core_filter_column "3")

  shellb_bookmark_del "$(_shellb_core_string_trim "${target}")"
}

function shellb_bookmark_list_purge() {
  _shellb_print_dbg "shellb_bookmark_listpurge(${1})"

  _shellb_core_get_user_confirmation "This will remove \"dead\" bookmarks. Bookmarks to accessible directories will be kept unchanged. Proceed?" || return 0

  # display bookmark names and paths
  local some_bookmarks_purged=0
  while read -r bookmark
  do
    # delete any bookmark that does not exist
    if ! _shellb_bookmark_is_alive "${bookmark}"; then
      [ ${some_bookmarks_purged} -eq 0 ] && _shellb_print_nfo "purged \"dead\" bookmarks:"
      # run in non-interactive mode
      shellb_bookmark_del "${bookmark}" "1"
      some_bookmarks_purged=1
    fi
  done < <(_shellb_bookmark_glob "*")

  [ ${some_bookmarks_purged} -eq 0 ] && _shellb_print_nfo "no bookmarks purged (all bookmarks were \"alive\")"
}

_SHELLB_BOOKMARK_ACTIONS="new del go edit list purge"

function _shellb_bookmark_action() {
  _shellb_print_dbg "_shellb_bookmark_action($*)"
  local action
  action=$1
  shift
  [ -n "${action}" ] || _shellb_print_err "no action given" || return 1

  case ${action} in
    help)
      # TODO: implement help
      _shellb_print_err "unimplemented \"bookmark $action\""
      ;;
    new)
      shellb_bookmark_set "$@"
      ;;
    del)
      shellb_bookmark_list_del "$@"
      ;;
    go)
      shellb_bookmark_list_goto "$@"
      ;;
    edit)
      # TODO: implement edit
      _shellb_print_err "unimplemented \"bookmark $action\""
      ;;
    list)
      shellb_bookmark_list_long "$@"
      ;;
    purge)
      shellb_bookmark_list_purge "$@"
      ;;
    *)
      _shellb_print_err "unknown action \"bookmark $action\""
      ;;
  esac
}

function _shellb_bookmark_compgen() {
  _shellb_print_dbg "_shellb_bookmark_compgen($*)"

  local comp_cur comp_prev opts
  comp_cur="${COMP_WORDS[COMP_CWORD]}"
  comp_prev="${COMP_WORDS[COMP_CWORD-1]}"
  _shellb_print_dbg "comp_cur: \"${comp_cur}\" COMP_CWORD: \"${COMP_CWORD}\""

  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()

  case $((COMP_CWORD)) in
    2)
      opts="${_SHELLB_BOOKMARK_ACTIONS} help"
      ;;
    3)
      case "${comp_prev}" in
        help)
          opts=${_SHELLB_BOOKMARK_ACTIONS}
          ;;
        new|purge)
          opts=""
          ;;
        del|go|edit|list)
          opts="$(shellb_bookmark_list_short "*")"
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