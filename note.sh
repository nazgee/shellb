
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
  target=$(_shellb_core_calc_user_to_domainabs "${selection}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_proto_from_domainabs "${target}" "${_SHELLB_DB_NOTES}")

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
  target=$(_shellb_core_calc_user_to_domainabs "${selection}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_proto_from_domainabs "${target}" "${_SHELLB_DB_NOTES}")

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
  target=$(_shellb_core_calc_user_to_domainabs "${selection}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_proto_from_domainabs "${target}" "${_SHELLB_DB_NOTES}")

  [ -f "${target}" ] || _shellb_print_err "notepad del failed, no \"${target}\" notepad" || return 1
  _shellb_core_user_get_confirmation "delete \"${proto_target}\" notepad?" || return 0
  _shellb_core_remove "${target}" || _shellb_print_err "notepad \"${notepad_domainfile}\" del failed, is it accessible?" || return 1
  _shellb_print_nfo "\"${proto_target}\" notepad deleted"
}

function shellb_notepad_delall() {
  _shellb_print_dbg "shellb_notepad_delall($*)"
  _shellb_core_user_get_confirmation "delete all notepads?" || return 0 && _shellb_print_nfo "deleting all notepads"

  # delete all notepads. this is a bit dangerous, but we have a confirmation step above
  # in case _SHELLB_DB_NOTES is not set, script should exit becase :? will fail
  _shellb_core_remove_dir "${_SHELLB_DB_NOTES}" || _shellb_print_err "notepad delall failed, is ${_SHELLB_DB_NOTES} accessible?" || return 1
  _shellb_print_nfo "all notepads deleted"
}

# Lists notes below given directory, or returns 1 if none found or given dir is invalid
# $1 - optional directory to list notes below (default: /, will find all notes)
function shellb_notepad_list() {
  _shellb_print_dbg "shellb_notepad_list($*)"
  local -n shellb_notepad_list_notes=$1
  shift
  local target proto_target user_dir
  user_dir=$(realpath -qe "${1:-/}" 2>/dev/null) || {
    _shellb_print_err "notepad list failed, \"${1}\" is not a valid dir"
    return 1
  }
  [ -d "${user_dir}" ] || {
    _shellb_print_err "notepad list failed, \"${user_dir}\" is not a dir"
    return 1
  }
  target=$(_shellb_core_calc_user_to_domainabs "${user_dir}" "${_SHELLB_DB_NOTES}")
  proto_target=$(_shellb_core_calc_proto_from_domainabs "${target}" "${_SHELLB_DB_NOTES}")

  mapfile -t shellb_notepad_list_notes < <(_shellb_core_find_domainrel "${_SHELLB_DB_NOTES}" "*" "${user_dir}") || {
    _shellb_print_err "notepads lookup failed, is ${_SHELLB_DB_NOTES} accessible?"
    return 1
  }

  [ ${#shellb_notepad_list_notes[@]} -gt 0 ] || {
    _shellb_print_err "notepad list failed, no notepads below \"${proto_target}\""
    return 1
  }

  if [ "${user_dir}" = "/" ]; then
    _shellb_print_nfo "all notepads in ${proto_target}"
  else
    _shellb_print_nfo "notepads below \"${proto_target}\""
  fi

  # print note files
  local i=0
  printf "IDX NOTE\n"
  for note in "${shellb_notepad_list_notes[@]}"; do
    i=$((i+1))
    printf "%3s %s\n" "${i}" "${note}"
  done
}

function _shellb_notes_select() {
  _shellb_print_dbg "_shellb_notes_select($*)"
  local prompt="${1}"
  shift
  local -n _shellb_notes_select_notepad=$1
  shift
  local user_dir
  user_dir="${1:-./${_SHELLB_CFG_NOTE_FILE}}"

  local -a _shellb_notes_select_notepads
  if [ -d "${user_dir}" ]; then
    shellb_notepad_list _shellb_notes_select_notepads "${user_dir}" || {
      _shellb_print_err "no notepad selected"
      return 1
    }

    if [ "${#_shellb_notes_select_notepads[@]}" -gt 1 ]; then
      _shellb_print_nfo "${prompt}"
      selection=$(_shellb_core_user_get_number "${#_shellb_notes_select_notepads[@]}") || return 1
    else
      selection=1
    fi
    _shellb_notes_select_notepad="${user_dir}/${_shellb_notes_select_notepads[selection-1]}"
  else
    # shellcheck disable=SC2034
    _shellb_notes_select_notepad="${user_dir}"
  fi

  return 0
}

function shellb_notepad_list_edit() {
  _shellb_print_dbg "shellb_notepad_list_edit($*)"
  local shellb_notepad_list_edit_target
  _shellb_notes_select "select notepad to edit:" shellb_notepad_list_edit_target "${1:-./${_SHELLB_CFG_NOTE_FILE}}" || {
    _shellb_print_err "notepad edit failed, no notepad selected"
    return 1
  }
  shellb_notepad_edit "${shellb_notepad_list_edit_target}"
}

function shellb_notepad_list_show() {
  _shellb_print_dbg "shellb_notepad_list_show($*)"
  local shellb_notepad_list_show_target
  _shellb_notes_select "select notepad to show:" shellb_notepad_list_show_target "${1:-./${_SHELLB_CFG_NOTE_FILE}}" || {
    _shellb_print_err "notepad show failed, no notepad selected"
    return 1
  }
  shellb_notepad_show "${shellb_notepad_list_show_target}"
}

# $1 - notepad or direcotry to delete. If it's a directory, ask user to select a notepad
function shellb_notepad_list_del() {
  _shellb_print_dbg "shellb_notepad_list_del($*)"
  local shellb_notepad_list_del_target
  _shellb_notes_select "select notepad to delete:" shellb_notepad_list_del_target "${1:-./${_SHELLB_CFG_NOTE_FILE}}" || {
    _shellb_print_err "notepad delete failed, no notepad selected"
    return 1
  }
  shellb_notepad_del "${shellb_notepad_list_del_target}"
}

_SHELLB_NOTE_ACTIONS="edit del cat list purge"

function shellb_notepad_help() {
  local action="$1"

  case "$action" in
    edit)
      echo "usage: shellb note edit [NOTEPAD_FILE]"
      echo ""
      echo "Opens shellb \"note\" file NOTEPAD_FILE in editor."
      echo "If NOTEPAD_FILE is not provided, ${_SHELLB_CFG_NOTE_FILE} will be used."
      echo ""
      _shellb_aliases_action "shellb note edit"
      ;;
    del)
      echo "usage: shellb note del [PATH]"
      echo ""
      echo "Deletes shellb \"note\" files under given PATH."
      echo "If PATH isnot provided or there are multiple \"note\" files under PATH, user will be asked to select a notepad to delete."
      echo ""
      _shellb_aliases_action "shellb note del"
      ;;
    cat)
      echo "usage: shellb note cat [PATH]"
      echo ""
      echo "Prints a list of shellb \"note\" files under given PATH to stdout."
      echo "If PATH is not provided or there are multiple \"note\" files under PATH, user will be asked to select a notepad to show."
      echo ""
      _shellb_aliases_action "shellb note cat"
      ;;
    list)
      echo "usage: shellb note cat [PATH]"
      echo ""
      echo "Prints a list of shellb \"note\" files under given PATH."
      echo "If PATH is not provided list of all available notes will be printed."
      echo ""
      _shellb_aliases_action "shellb note list"
      ;;
    purge)
      echo "usage: shellb note purge"
      echo ""
      echo "Deletes \"note\" files that are created for directories that no longer exist."
      echo "This is useful to clean up bookmarks after substantial changed to the filesysytem."
      echo ""
      _shellb_aliases_action "shellb note purge"
      ;;
    *)
      echo "\"note\" module allows to create notes for a directory in a shellb database, and edit them later."
      echo "shellb \"note\" is persistent - it will be available even if directory is deleted"
      echo ""
      echo "usage: shellb note ACTION"
      echo ""
      echo "\"shellb note\" actions:"
      echo "    edit     Edit notepad"
      echo "    del      Delete notepad"
      echo "    cat      Show notepad"
      echo "    list     Lit notepads"
      echo "    purge    delete all notepads"
      echo ""
      echo "See \"shellb note help <action>\" for more information on a specific action."
      echo ""
      _shellb_aliases_action "shellb note"
      ;;
  esac
  return 0
}

function _shellb_note_action() {
  _shellb_print_dbg "_shellb_note_action($*)"
  local action
  action=$1
  shift
  [ -n "${action}" ] || _shellb_print_err "no action given" || return 1

  case ${action} in
    help)
      shellb_notepad_help "$@"
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
      local -a _shellb_note_action_list_dummy
      shellb_notepad_list _shellb_note_action_list_dummy "$@"
      ;;
    purge)
      _shellb_print_err "unimplemented \"note $action\""
      ;;
    *)
      _shellb_print_err "unknown action \"note $action\""
      ;;
  esac
  return 0
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

  case $COMP_CWORD in
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
          opts=""
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
