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

echo "bookmark extension loading..."

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
  _shellb_core_calc_absfile "${1}" "${_SHELLB_DB_BOOKMARKS}" "/"
}

function _shellb_bookmark_glob(){
  _shellb_core_domain_files_ls "${_SHELLB_DB_BOOKMARKS}" "${1}" "/"
}

function _shellb_bookmark_get() {
  _shellb_print_dbg "_shellb_bookmark_get(${1})"
  # check if bookmark name is given
  [ -n "${1}" ] || return 1
  cat "$(_shellb_bookmarks_calc_absfile "${1}")" 2> /dev/null
}

function _shellb_bookmark_print_long_alive() {
  printf "${_SHELLB_CFG_SYMBOL_CHECK} %-18s: %s\n" "${1}" "${2}"
}

function _shellb_bookmark_print_long_dangling() {
  printf "${_SHELLB_CFG_SYMBOL_CROSS} %-18s: ${_SHELLB_CFG_COLOR_ERR}%s${_SHELLB_COLOR_NONE}\n" "${1}" "${2}"
}

function _shellb_bookmark_print_long() {
  # check if target is "alive" or "dangling"
  if [[ -d "${2}" ]]; then
    _shellb_bookmark_print_long_alive "${1}" "${2}"
  else
    _shellb_bookmark_print_long_dangling "${1}" "${2}"
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
      _shellb_core_get_user_confirmation "bookmark \"${bookmark_name}\" to \"$(_shellb_bookmark_get "${bookmark_name})")\" exists, overwrite?" || return 0
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
    printf "%3s) " "${i}"
    shellb_bookmark_get_long "${bookmark}"
    i=$(($i+1))
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
  local list target
  list=$(shellb_bookmark_list_long "${1}")  || return 1
  echo "$list"

  _shellb_print_nfo "select bookmark to goto:"
  # if number is given by the user, it will be translated to 3rd column
  target=$(_shellb_core_get_user_selection_column "$list" "3")
  shellb_bookmark_goto "${target}"
}

function shellb_bookmark_list_del() {
  local list target
  list=$(shellb_bookmark_list_long "${1}")  || return 1
  echo "$list"

  _shellb_print_nfo "select bookmark to delete:"
  # if number is given by the user, it will be translated to 3rd column
  target=$(_shellb_core_get_user_selection_column "$list" "3")
  shellb_bookmark_del "${target}"
}

function shellb_bookmark_list_purge() {
  _shellb_print_dbg "shellb_bookmark_listpurge(${1})"

  _shellb_core_get_user_confirmation "This will remove \"dead\" bookmarks. Bookmarks to accessible directories will be kept unchanged. Proceed?" || return 0

  # display bookmark names and paths
  local PURGED=0
  while read -r bookmark
  do
    # get bookmarked directory and save it in target
    local target
    target=$(_shellb_bookmark_get "${bookmark}")

    # delete any target that does not exist
    # and print a banner message if any bookmark was deleted
    if [[ ! -e "${target}" ]]; then
      [ ${PURGED} -eq 0 ] && _shellb_print_nfo "purged \"dead\" bookmarks:"
      # run in non-interactive mode
      shellb_bookmark_del "${bookmark}" "1"
      PURGED=1
    fi

    # reset target
    target=""
  done < <(_shellb_bookmark_glob "*")

  [ ${PURGED} -eq 0 ] && _shellb_print_nfo "no bookmarks purged (all bookmarks were \"alive\")"
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
      _shellb_print_err "unimplemented \"bookmark $action\""
      ;;
    new)
      shellb_bookmark_set "$@"
      ;;
    del)
      shellb_bookmark_del "$@"
      ;;
    go)
      shellb_bookmark_goto "$@"
      ;;
    edit)
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

function _shellb_bookmark_completion_opts() {
  _shellb_print_dbg "_shellb_bookmark_completion_opts($*)"

  local comp_words comp_cword comp_cur comp_prev opts
  comp_cword=$1
  shift
  comp_words=( $@ )
  comp_cur="${comp_words[$comp_cword]}"
  comp_prev="${comp_words[$comp_cword-1]}"

  case ${comp_cword} in
    1)
      opts="${_SHELLB_BOOKMARK_ACTIONS} help"
      ;;
    2)
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

  echo "${opts}"
}