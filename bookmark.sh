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

_SHELLB_DB_BOOKMARKS="${_SHELLB_DB}/bookmarks"
[ ! -e "${_SHELLB_DB_BOOKMARKS}" ] && mkdir -p "${_SHELLB_DB_BOOKMARKS}"

###############################################
# bookmark functions
###############################################
function _shellb_bookmarks_calc_absfile() {
  _shellb_print_dbg "_shellb_bookmarks_calc_absfile(${1})"
  # this is a bit slow due to realpath:
  #_shellb_core_calc_user_to_domainabs "/${1}" "${_SHELLB_DB_BOOKMARKS}"
  # this is faster:
  echo "${_SHELLB_DB_BOOKMARKS}/${1}"
}

function _shellb_bookmark_glob() {
  _shellb_print_dbg "_shellb_bookmark_glob($*)"
  local glob
  glob="${1:-*}"
  _shellb_core_ls_domainrel "${_SHELLB_DB_BOOKMARKS}" "${glob}.${_SHELLB_CFG_BOOKMARK_EXT}" "/" | sed "s/.${_SHELLB_CFG_BOOKMARK_EXT}//g" | tr ' ' '\n' | sort
}

function _shellb_bookmark_get() {
  _shellb_print_dbg "_shellb_bookmark_get($*)"
  # check if bookmark name is given
  [ -n "${1}" ] || return 1
  cat "$(_shellb_bookmarks_calc_absfile "${1}.${_SHELLB_CFG_BOOKMARK_EXT}")" 2> /dev/null
}

function _shellb_bookmark_is_alive() {
  _shellb_print_dbg "_shellb_bookmark_is_alive($*)"
  # check if bookmark name is given
  [ -n "${1}" ] || return 1
  [ -d "$(_shellb_bookmark_get "${1}")" ]
}

function _shellb_get_userdir_bookmarks() {
  _shellb_print_dbg "_shellb_get_userdir_bookmarks($*)"
  local userdir
  userdir="${1}"
  [ -n "${userdir}" ] || { _shellb_print_err "user_dir not given"; return 1 ; }
  userdir=$(realpath -mq "${userdir}")
  for bookmark_file in $(_shellb_core_ls_domainabs_matching_whole_line "${_SHELLB_DB_BOOKMARKS}" "*.${_SHELLB_CFG_BOOKMARK_EXT}" "/" "${userdir}") ; do
    printf "%s\n" "$(basename "${bookmark_file%".${_SHELLB_CFG_BOOKMARK_EXT}"}")"
  done

  return 0
}

function _shellb_pwd_bookmarks() {
    local matching_files
    matching_files=$(grep -Flx "$PWD" "${_SHELLB_DB_BOOKMARKS}"/*."${_SHELLB_CFG_BOOKMARK_EXT}")

    if [ -n "$matching_files" ]; then
        matching_files=${matching_files//"${_SHELLB_DB_BOOKMARKS}/"/}
        matching_files=${matching_files//.${_SHELLB_CFG_BOOKMARK_EXT}/}
        matching_files=${matching_files//$'\n'/,}
        echo "[${matching_files}]"
    else
        echo ""
    fi
}

function shellb_bookmark_set() {
  _shellb_print_dbg "_shellb_bookmark_set(${1}, ${2})"
  local bookmark_name="${1}"
  local bookmark_target="${2:-$(pwd)}"
  local bookmark_file

  # Validate input and check for existing bookmarks
  [ -n "${bookmark_name}" ] || { _shellb_print_err "set bookmark failed, no bookmark name given"; return 1; }
  bookmark_target=$(realpath "${bookmark_target}")
  [ -e "${bookmark_target}" ] || { _shellb_print_err "set bookmark failed, invalid directory (${bookmark_target})"; return 1; }

  bookmark_file="$(_shellb_bookmarks_calc_absfile "${bookmark_name}.${_SHELLB_CFG_BOOKMARK_EXT}")"
  if [ -e "${bookmark_file}" ] && ! echo "${bookmark_target}" | cmp -s - "${bookmark_file}" > /dev/null; then
    _shellb_core_user_get_confirmation "bookmark \"${bookmark_name}\" to \"$(_shellb_bookmark_get "${bookmark_name}")\" exists, change it to \"${bookmark_target}\"?" || return 0
  fi

  # Save the bookmark
  echo "${bookmark_target}" > "${bookmark_file}" || { _shellb_print_err "set bookmark failed, saving bookmark failed"; return 1; }

  _shellb_print_nfo "bookmark set:"
  shellb_bookmark_get_long "${1}"
}


# $1 name of bookmark to delete
# $2 if given, don't ask for confirmation
function shellb_bookmark_del() {
  _shellb_print_dbg "shellb_bookmark_del($*)"

  local bookmark_name assume_yes
  bookmark_name="${1}"
  assume_yes="${2}"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "del bookmark failed, no bookmark name given" || return 1
  [ -e "$(_shellb_bookmarks_calc_absfile "${1}.${_SHELLB_CFG_BOOKMARK_EXT}")" ] || _shellb_print_err "del bookmark failed, unknown bookmark: \"${1}\"" || return 1
  [ -n "${assume_yes}" ] || _shellb_core_user_get_confirmation "delete \"${1}\" bookmark?" || return 0
  _shellb_core_remove "$(_shellb_bookmarks_calc_absfile "${1}.${_SHELLB_CFG_BOOKMARK_EXT}")" || _shellb_print_err "del bookmark failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1
  _shellb_print_nfo "bookmark deleted: ${1}"
}

function shellb_bookmark_goto() {
  _shellb_print_dbg "shellb_bookmark_goto($*)"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "goto bookmark failed, no bookmark name given" || return 1

  # check if given bookmark exists
  [ -e "$(_shellb_bookmarks_calc_absfile "${1}.${_SHELLB_CFG_BOOKMARK_EXT}")" ] || _shellb_print_err "goto bookmark failed, unknown bookmark: \"${1}\"" || return 1

  # get bookmarked directory
  local target
  target=$(_shellb_bookmark_get "${1}") || _shellb_print_err "goto bookmark failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1

  # go to bookmarked directory
  cd "${target}" || _shellb_print_err "goto bookmark failed, bookmark to dangling directory or no permissions to enter it" || return 1
}

function shellb_bookmark_edit() {
  _shellb_print_dbg "shellb_bookmark_edit($*)"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "edit bookmark failed, no bookmark name given" || return 1

  # check if given bookmark exists
  [ -e "$(_shellb_bookmarks_calc_absfile "${1}.${_SHELLB_CFG_BOOKMARK_EXT}")" ] || _shellb_print_err "edit bookmark failed, unknown bookmark: \"${1}\"" || return 1

  local bookmark="${1}"
  # get bookmarked directory
  local target
  target=$(_shellb_bookmark_get "${1}") || _shellb_print_err "edit bookmark failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1

  # edit bookmark
  read -r -e -p "bookmark name  : " -i "${bookmark}" bookmark || return 1
  read -r -e -p "bookmark target: " -i "${target}" target || return 1
  shellb_bookmark_set "${bookmark}" "${target}" || return 1
}

function shellb_bookmark_get_short() {
  _shellb_print_dbg "shellb_bookmark_get_short(${1})"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "get bookmark failed, no bookmark name given" || return 1
  # print the bookmark name or display an error message
  _shellb_bookmark_get "${1}" || _shellb_print_err "get bookmark failed, unknown bookmark" || return 1
}

# Print a single line of bookmark information
# $1 name of bookmark
# $2 target of bookmark
# $3 bookmark name column width
function _shellb_bookmark_print_long() {
  _shellb_print_dbg "_shellb_bookmark_print_long($*)"
  local column_width="$3"
  if _shellb_bookmark_is_alive "$1"; then
    printf "${_SHELLB_CFG_SYMBOL_CHECK} | %${column_width}s | %s\n" "${1}" "${2}"
  else
    printf "${_SHELLB_CFG_SYMBOL_CROSS} | %${column_width}s | ${_SHELLB_CFG_COLOR_ERR}%s${_SHELLB_COLOR_NONE}\n" "${1}" "${2}"
  fi
}

function shellb_bookmark_get_long() {
  _shellb_print_dbg "shellb_bookmark_get_long(${1})"

  # check if bookmark is known, and save it in target
  local target
  target=$(shellb_bookmark_get_short "$1") || return 1 # error message already printed
  _shellb_bookmark_print_long "${1}" "${target}"
}

function shellb_bookmark_list_long() {
  _shellb_print_dbg "shellb_bookmark_list_long($*)"

  # fetch all bookmarks or only those starting with given glob expression
  local -n shellb_bookmark_list_long_bookmarks=$1
  shift
  mapfile -t shellb_bookmark_list_long_bookmarks < <(_shellb_bookmark_glob "${1}")

  # check any bookmarks were found
  [ ${#shellb_bookmark_list_long_bookmarks[@]} -gt 0 ] || _shellb_print_wrn_fail "no bookmarks matching \"${1}\" glob expression" || return 1

  # calculate max length of bookmark name
  local bookmarks_len=0
  for bookmark in "${shellb_bookmark_list_long_bookmarks[@]}"; do
    (( ${#bookmark} > bookmarks_len )) && bookmarks_len=${#bookmark}
  done
  (( 4 > bookmarks_len )) && bookmarks_len=4

  printf "LIVE | %-${bookmarks_len}s | IDX | TARGET\n" "NAME"
  # print out bookmarks
  local prev_target prev_bookmark target_common bookmark_common
  for ((i=0; i<${#shellb_bookmark_list_long_bookmarks[@]}; i++)); do
    local bookmark="${shellb_bookmark_list_long_bookmarks[i]}"
    local target
    target=$(shellb_bookmark_get_short "${bookmark}") || return 1 # error message already printed

    # calculate common and unique part between previous and current target
    target_common=$(_shellb_core_calc_common_part "${target}" "${prev_target}" "$(shellb_bookmark_get_short "${shellb_bookmark_list_long_bookmarks[i+1]}" 2>/dev/null)")
    # target_common=$(_shellb_core_calc_common_part_sticky "${prev_target}" "${target}" "${target_common}")
    local target_unique="${target#"${target_common}"}"
    # calculate common and unique part between previous and current bookmark
    bookmark_common=$(_shellb_core_calc_common_part_sticky "${prev_bookmark}" "${bookmark}" "${bookmark_common}")
    local bookmark_unique="${bookmark#"${bookmark_common}"}"

    if _shellb_bookmark_is_alive "${bookmark}"; then
      printf "  ${_SHELLB_CFG_SYMBOL_CHECK}  | ${_SHELLB_CFG_COLOR_REF}%s${_SHELLB_COLOR_NONE}%-$((bookmarks_len - ${#bookmark_common}))s | %3s | ${_SHELLB_CFG_COLOR_REF}%s${_SHELLB_COLOR_NONE}%s\n" \
        "${bookmark_common}" "${bookmark_unique}" "$((i+1))" "${target_common}" "${target_unique}"
    else
      printf "  ${_SHELLB_CFG_COLOR_ERR}${_SHELLB_CFG_SYMBOL_CROSS}${_SHELLB_COLOR_NONE}  | ${_SHELLB_CFG_COLOR_REF}%s${_SHELLB_COLOR_NONE}%-$((bookmarks_len - ${#bookmark_common}))s | ${_SHELLB_CFG_COLOR_ERR}%3s${_SHELLB_COLOR_NONE} | ${_SHELLB_CFG_COLOR_REF}%s${_SHELLB_COLOR_NONE}%s\n" \
        "${bookmark_common}" "${bookmark_unique}" "$((i+1))" "${target_common}" "${target_unique}"
    fi

    prev_bookmark=${bookmark}
    prev_target=${target}
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

function _shellb_bookmark_select() {
  _shellb_print_dbg "_shellb_bookmark_select($*)"
  local prompt="${1}"
  shift
  local -n _shellb_bookmark_select_bookmark=$1
  shift
  local -a _shellb_bookmark_select_bookmarks
  shellb_bookmark_list_long _shellb_bookmark_select_bookmarks "${1}"  || return 1

  # if we have some bookmarks, let user choose
  local selection
  if [[ ${#_shellb_bookmark_select_bookmarks[@]} -gt 1 ]]; then
    _shellb_print_nfo "${prompt}"
    selection=$(_shellb_core_user_get_number "${#_shellb_bookmark_select_bookmarks[@]}") || return 1
  else
    selection="1"
  fi

  # shellcheck disable=SC2034
  _shellb_bookmark_select_bookmark="${_shellb_bookmark_select_bookmarks[selection-1]}"
}

function shellb_bookmark_list_goto() {
  local shellb_bookmark_list_goto_bookmark
  _shellb_print_dbg "shellb_bookmark_list_goto($*)"
  _shellb_bookmark_select "select bookmark to goto" shellb_bookmark_list_goto_bookmark "${1}" || return 1
  shellb_bookmark_goto "${shellb_bookmark_list_goto_bookmark}"
}

function shellb_bookmark_list_del() {
  local shellb_bookmark_list_del_bookmark
  _shellb_print_dbg "shellb_bookmark_list_del($*)"
  _shellb_bookmark_select "select bookmark to delete" shellb_bookmark_list_del_bookmark "${1}" || return 1
  shellb_bookmark_del "${shellb_bookmark_list_del_bookmark}"
}

function shellb_bookmark_list_edit() {
  local shellb_bookmark_list_edit_bookmark
  _shellb_print_dbg "shellb_bookmark_list_edit($*)"
  _shellb_bookmark_select "select bookmark to edit" shellb_bookmark_list_edit_bookmark "${1}" || return 1
  shellb_bookmark_edit "${shellb_bookmark_list_edit_bookmark}"
}

function shellb_bookmark_list_purge() {
  _shellb_print_dbg "shellb_bookmark_listpurge(${1})"

  _shellb_core_user_get_confirmation "This will remove \"dead\" bookmarks. Bookmarks to accessible directories will be kept unchanged. Proceed?" || return 0

  # display bookmark names and paths
  local some_bookmarks_purged=0
  while read -r bookmark
  do
    # delete any bookmark that does not exist
    if ! _shellb_bookmark_is_alive "${bookmark}"; then
      # before deleting, print a header
      [ ${some_bookmarks_purged} -eq 0 ] && _shellb_print_nfo "purged \"dead\" bookmarks:"
      # delete in non-interactive mode (no confirmation needed)
      shellb_bookmark_del "${bookmark}" "1"
      some_bookmarks_purged=1
    fi
  done < <(_shellb_bookmark_glob "*")

  [ ${some_bookmarks_purged} -eq 0 ] && _shellb_print_nfo "no bookmarks purged (all bookmarks were \"alive\")"
}

function bookmark_bookmark_help() {
  local action="$1"

  case "$action" in
    new)
      echo "Usage: bookmark new [bookmark_name] [bookmark_path]"
      echo "Creates a new bookmark with the specified name and path."
      echo "If no name is specified, the current directory name is used as the name."
      echo "If no path is specified, the current directory path is used as the path."
      ;;
    del)
      echo "Usage: bookmark del [bookmark_name]"
      echo "Deletes the bookmark with the specified name."
      ;;
    go)
      echo "Usage: bookmark go [bookmark_name]"
      echo "Navigates to the directory associated with the specified bookmark."
      ;;
    edit)
      echo "Usage: bookmark edit [bookmark_name]"
      echo "Opens the bookmark file for editing in the default editor."
      ;;
    list)
      echo "Usage: bookmark list"
      echo "Lists all available bookmarks and their associated paths."
      ;;
    purge)
      echo "Usage: bookmark purge"
      echo "Deletes all existing bookmarks."
      ;;
    *)
      echo "Usage: bookmark help [action]"
      echo "Displays help information for the specified action."
      echo "Actions: new, del, go, edit, list, purge"
      ;;
  esac
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
      bookmark_bookmark_help "$@"
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
      shellb_bookmark_list_edit "$@"
      ;;
    list)
      local -a _shellb_bookmark_action_list_dummy
      shellb_bookmark_list_long _shellb_bookmark_action_list_dummy "$@"
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

  case $COMP_CWORD in
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

