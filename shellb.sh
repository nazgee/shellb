# Shell Bookmarks for BASH (c) 2023 Michal Stawinski, Version 1
#
# Concept based on DirB / Directory Bookmarks for BASH (c) 2009-2010 by Ira Chayut
#
# To add to your bass, save this file <ANYWHERE>, and add the following line to ~/.bashrc:
#
#        source <ANYWHERE>/shellb.sh


###############################################
# Variables
###############################################
# paths
_SHELLB_RC="$(realpath -q ~/.shellbrc)"
_SHELLB_DB="$(realpath -q ~/.shellB)"
_SHELLB_DB_BOOKMARKS="${_SHELLB_DB}/bookmarks"
_SHELLB_DB_NOTES="${_SHELLB_DB}/notes"
_SHELLB_DB_COMMANDS="${_SHELLB_DB}/commands"

# colors
_SHELLB_COLOR_NONE="\e[m"
_SHELLB_COLOR_BLUE="\e[00;34m"
_SHELLB_COLOR_CYAN="\e[00;36m"
_SHELLB_COLOR_GREEN="\e[00;32m"
_SHELLB_COLOR_PURPLE="\e[00;35m"
_SHELLB_COLOR_RED="\e[00;31m"
_SHELLB_COLOR_WHITE="\e[00;37m"
_SHELLB_COLOR_YELLOW="\e[00;33m"
_SHELLB_COLOR_BLUE_B="\e[01;34m"
_SHELLB_COLOR_CYAN_B="\e[01;36m"
_SHELLB_COLOR_GREEN_B="\e[01;32m"
_SHELLB_COLOR_PURPLE_B="\e[01;35m"
_SHELLB_COLOR_RED_B="\e[01;31m"
_SHELLB_COLOR_WHITE_B="\e[01;37m"
_SHELLB_COLOR_YELLOW_B="\e[01;33m"

# symbols
_SHELLB_SYMBOL_CHECK="\u2714"
_SHELLB_SYMBOL_CROSS="\u2716"

# config
_SHELLB_CFG_DEBUG=0
_SHELLB_CFG_COLOR_NFO=""
_SHELLB_CFG_COLOR_WRN=${_SHELLB_COLOR_YELLOW_B}
_SHELLB_CFG_COLOR_ERR=${_SHELLB_COLOR_RED_B}
_SHELLB_CFG_SYMBOL_CHECK=${_SHELLB_SYMBOL_CHECK}
_SHELLB_CFG_SYMBOL_CROSS=${_SHELLB_SYMBOL_CROSS}
_SHELLB_CFG_LOG_PREFIX="shellb"
_SHELLB_CFG_NOTE_FILE="note.md"

_SHELLB_CFG_RC_DEFAULT=\
'# core functions
shellb_func_core_help = h

# bookmark functions
shellb_func_bookmark_set = s
shellb_func_bookmark_del = r
shellb_func_bookmark_get_short = ds
shellb_func_bookmark_get_long = d
shellb_func_bookmark_goto = g
shellb_func_bookmark_list_short = sls
shellb_func_bookmark_list_long = sl
shellb_func_bookmark_list_purge = slp

# notepad functions
shellb_func_notepad_edit = npe
shellb_func_notepad_show = nps
shellb_func_notepad_list = npl
shellb_func_notepad_del  = npd
shellb_func_notepad_get  = npg
shellb_func_notepad_calc = npc
shellb_func_notepad_delall  = npda

# command functions

'


###############################################
# helper functions
###############################################
function _shellb_print_dbg() {
  [ ${_SHELLB_CFG_DEBUG} -eq 1 ] && printf "${_SHELLB_CFG_LOG_PREFIX}: DEBUG: ${_SHELLB_CFG_COLOR_NFO}%s${_SHELLB_COLOR_NONE}\n" "${1}" >&2
}

function _shellb_print_nfo() {
  printf "${_SHELLB_CFG_LOG_PREFIX}: ${_SHELLB_CFG_COLOR_NFO}%s${_SHELLB_COLOR_NONE}\n" "${1}"
}

function _shellb_print_wrn() {
  printf "${_SHELLB_CFG_LOG_PREFIX}: ${_SHELLB_CFG_COLOR_WRN}%s${_SHELLB_COLOR_NONE}\n" "${1}" >&2
  # for failures chaining
  return 1
}

function _shellb_print_err() {
  printf "${_SHELLB_CFG_LOG_PREFIX}: ${_SHELLB_CFG_COLOR_ERR}%s${_SHELLB_COLOR_NONE}\n" "${1}" >&2
  # for failures chaining
  return 1
}

function _shellb_print_keyvalue_ok() {
  printf "${_SHELLB_CFG_SYMBOL_CHECK} %-18s: %s\n" "${1}" "${2}"
}

function _shellb_print_keyvalue_err() {
  printf "${_SHELLB_CFG_SYMBOL_CROSS} %-18s: ${_SHELLB_CFG_COLOR_ERR}%s${_SHELLB_COLOR_NONE}\n" "${1}" "${2}"
}

###############################################
# init
###############################################
# prepare DB for bookmarks, notes, and commands
[ ! -e "${_SHELLB_DB_BOOKMARKS}" ] && mkdir -p "${_SHELLB_DB_BOOKMARKS}"
[ ! -e "${_SHELLB_DB_NOTES}" ] && mkdir -p "${_SHELLB_DB_NOTES}"
[ ! -e "${_SHELLB_DB_COMMANDS}" ] && mkdir -p "${_SHELLB_DB_COMMANDS}"

# load config file - this will declare variables that we'll use later
while IFS='= ' read -r lhs rhs
do
    if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
        rhs="${rhs%%\#*}"              # Del in line right comments
        rhs="${rhs%"${rhs##*[^ ]}"}"   # Del trailing spaces
        rhs="${rhs%\"*}"               # Del opening string quotes
        rhs="${rhs#\"*}"               # Del closing string quotes
        declare $lhs="$rhs"
    fi
done < "${_SHELLB_RC}"

# check if required tools are available
[ -e "$(command -v realpath)" ] || _shellb_print_err "realpath not found. Please install coreutils."
[ -e "$(command -v head)" ] || _shellb_print_err "head not found. Please install coreutils."
[ -e "$(command -v xargs)" ] || _shellb_print_err "xargs not found. Please install findutils."
[ -e "$(command -v find)" ] || _shellb_print_err "find not found. Please install findutils."
[ -e "$(command -v sed)" ] || _shellb_print_err "sed not found. Please install sed"

# provide default config it not present
[ -e "${_SHELLB_RC}" ] || _shellb_print_wrn "creating default config: ${_SHELLB_RC}" \
  || echo "${_SHELLB_CFG_RC_DEFAULT}" > "${_SHELLB_RC}"

###############################################
# bookmark functions
###############################################
function _shellb_bookmarks_column() {
  # list bookmarks line by line
  # we do it in subshell to avoid changing directory for whoever called us
    ( cd "${_SHELLB_DB_BOOKMARKS}" || _shellb_print_err "failed to fetch bookmarks row, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1; \
      ls -1 "${1}"* )
}

function _shellb_bookmarks_row() {
  # list bookmarks in a single line
  # we do it in subshell to avoid changing directory for whoever called us
  ( cd "${_SHELLB_DB_BOOKMARKS}" || _shellb_print_err "failed to fetch bookmarks row, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1; \
    ls -x "${1}"* )
}

function _shellb_bookmark_get() {
  _shellb_print_dbg "_shellb_bookmark_get(${1})"
  # check if bookmark name is given
  [ -n "${1}" ] || return 1

  if [ -e "${_SHELLB_DB_BOOKMARKS}/${1}" ]; then
    cat "${_SHELLB_DB_BOOKMARKS}/${1}"
  else
    return 1
  fi
}

function shellb_bookmark_set() {
  _shellb_print_dbg "_shellb_bookmark_set(${1}, ${2})"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "set bookmark failed, bookmark name can't be empty" || return 1

  # if second arg is not given, bookmark current directory
  local TARGET
  TARGET="${2}"
  [ -z "${TARGET}" ] && TARGET="$(pwd)"

  # translate relative paths to absolute paths
  TARGET=$(realpath "${TARGET}")

  # check if bookmark directory exists
  [ -e "${TARGET}" ] || _shellb_print_err "set bookmark failed, invalid directory (${TARGET})" || return 1

  # build the bookmark file with the contents "$CD directory_path"
  echo "$TARGET" > "${_SHELLB_DB_BOOKMARKS}/${1}" || _shellb_print_err "set bookmark failed, saving bookmark failed" || return 1

  _shellb_print_nfo "bookmark set:"
  shellb_bookmark_get_long "${1}"
}

function shellb_bookmark_del() {
  _shellb_print_dbg "shellb_bookmark_del(${1})"

  [ -e "${_SHELLB_DB_BOOKMARKS}/${1}" ] || _shellb_print_err "del bookmark failed, unknown bookmark" || return 1
  rm "${_SHELLB_DB_BOOKMARKS}/${1}" 2>/dev/null || _shellb_print_err "del bookmark failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1
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

  # check if bookmark is known, and save it in TARGET
  local TARGET
  TARGET=$(shellb_bookmark_get_short "$1") || return 1 # error message already printed

  # check if TARGET is "alive" or "dangling"
  if [[ -d "${TARGET}" ]]; then
    _shellb_print_keyvalue_ok "${1}" "${TARGET}"
  else
    _shellb_print_keyvalue_err "${1}" "${TARGET}"
  fi
}

function shellb_bookmark_goto() {
  _shellb_print_dbg "shellb_bookmark_goto(${1})"

  # check if bookmark name is given
  [ -n "${1}" ] || _shellb_print_err "goto bookmark failed, no bookmark name given" || return 1

  # check if given bookmark exists
  [ -e "${_SHELLB_DB_BOOKMARKS}/${1}" ] || _shellb_print_err "goto bookmark failed, unknown bookmark" || return 1

  # get bookmarked directory
  local TARGET
  TARGET=$(cat "${_SHELLB_DB_BOOKMARKS}/${1}" 2>/dev/null) || _shellb_print_err "goto bookmark failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1

  # go to bookmarked directory
  cd "${TARGET}" || _shellb_print_err "goto bookmark failed, bookmark to dangling directory or no permissions to enter it" || return 1
}

function shellb_bookmark_list_long() {
  _shellb_print_dbg "shellb_bookmark_list_long(${1})"

  # display long form of all bookmarks or only those starting with given string
  while read -r bookmark
  do
    shellb_bookmark_get_long "${bookmark}"
  done < <(_shellb_bookmarks_column "${1}")
}

function shellb_bookmark_list_short() {
  _shellb_print_dbg "shellb_bookmark_list_short(${1})"

  # display long form of all bookmarks or only those starting with given string
  _shellb_bookmarks_row "${1}"
  #cd "${_SHELLB_DB_BOOKMARKS}" || _shellb_print_err "list bookmarks failed, is ${_SHELLB_DB_BOOKMARKS} accessible?" || return 1
  #ls "${1}"*
}

function shellb_bookmark_list_purge() {
  _shellb_print_dbg "shellb_bookmark_listpurge(${1})"

  # display bookmark names and paths
  local PURGED=0
  while read -r bookmark
  do
    # get bookmarked directory and save it in TARGET
    local TARGET
    TARGET=$(_shellb_bookmark_get "${bookmark}")

    # delete any target that does not exist
    # and print a banner message if any bookmark was deleted
    if [[ ! -e "${TARGET}" ]]; then
      [ ${PURGED} -eq 0 ] && _shellb_print_nfo "purged bookmarks:"
      shellb_bookmark_del "${bookmark}"
      PURGED=1
    fi

    # reset TARGET
    TARGET=""
  done < <(_shellb_bookmarks_column)

  [ ${PURGED} -eq 0 ] && _shellb_print_nfo "no bookmarks purged"
}

###############################################
# bookmark completion functions
###############################################
function _shellb_bookmark_completions() {
  local cur prev opts

  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete bookmark name or null
  prev="${COMP_WORDS[COMP_CWORD-1]}" # previous complete word, we're not interested, but it's here for reference
  opts="$(_shellb_bookmarks_row "")" # fetch full list of bookmarks, compgen will filter it

  # if cur is empty, we're completing bookmark name
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}

###############################################
# notepad functions
###############################################
function _shellb_notepad_calc_dir() {
  _shellb_print_dbg "_shellb_notepad_calc_dir()"
  echo "${_SHELLB_DB_NOTES}$(pwd)"
}

function shellb_notepad_calc() {
  _shellb_print_dbg "_shellb_notepad_calc_file()"
  echo "$(_shellb_notepad_calc_dir)/${_SHELLB_CFG_NOTE_FILE}"
}

function shellb_notepad_get() {
  _shellb_print_dbg "shellb_notepad_get()"
  [ -e "$(_shellb_notepad_calc_file)" ] || _shellb_print_err "notepad get failed, no notepad for this dir" || return 1
  _shellb_notepad_calc_file
}

function shellb_notepad_edit() {
  _shellb_print_dbg "shellb_notepad_edit($*)"
  mkdir -p "$(_shellb_notepad_calc_dir)" || _shellb_print_err "notepad edit failed, is ${_SHELLB_DB_NOTEPADS} accessible?" || return 1
  vim "$(_shellb_notepad_calc_file)"
}

function shellb_notepad_show() {
  _shellb_print_dbg "shellb_notepad_show($*)"
  [ -e "$(_shellb_notepad_calc_file)" ] || _shellb_print_err "notepad show failed, no notepad for this dir" || return 1
  [ -s "$(_shellb_notepad_calc_file)" ] || _shellb_print_wrn "notepad show: notepad is empty" || return 1
  cat "$(_shellb_notepad_calc_file)" || _shellb_print_err "notepad show failed, is ${_SHELLB_DB_NOTEPADS }accessible?" || return 1
}

function shellb_notepad_list() {
  _shellb_print_dbg "shellb_notepad_list($*)"
  find "${_SHELLB_DB_NOTES}" -name "${_SHELLB_CFG_NOTE_FILE}" || _shellb_print_err "notepad list failed, is ${_SHELLB_DB_NOTEPADS} accessible?" || return 1
}

function shellb_notepad_del() {
  _shellb_print_dbg "shellb_notepad_del($*)"
  rm "$(_shellb_notepad_calc_file)" || _shellb_print_err "notepad del failed, no notepad fot this dir" || return 1
  _shellb_print_nfo "notepad deleted"
}

function shellb_notepad_delall() {
  _shellb_print_dbg "shellb_notepad_delall($*)"
  rm "${_SHELLB_DB_NOTES:?}"/* -rf
  _shellb_print_nfo "all notepads deleted"
}

###############################################
# command functions
###############################################
# TODO implement

###############################################
# core functions
###############################################
# TODO implement
function shellb_core_help() {
  _shellb_print_wrn "not implemented yet"
}

###############################################
# shortcuts
# (these are just aliases to the core functions)
###############################################
# note, that we invoke shellb_ functions in subshell (parenthesis operator),
# to avoid polluting current shell with any side effects of shellb_ functions

#core functions
eval "${shellb_func_core_help}()                    { (shellb_core_help           \$@;) }"

# bookmark functions
eval "function ${shellb_func_bookmark_set}()        { (shellb_bookmark_set      \"\$@\";) }"
eval "function ${shellb_func_bookmark_del}()        { (shellb_bookmark_del        \$@;) }"
eval "function ${shellb_func_bookmark_get_short}()  { (shellb_bookmark_get_short  \$@;) }"
eval "function ${shellb_func_bookmark_get_long}()   { (shellb_bookmark_get_long   \$@;) }"
eval "function ${shellb_func_bookmark_goto}()       {  shellb_bookmark_goto       \$@;  }" # no subshell, we need side effects
eval "function ${shellb_func_bookmark_list_short}() { (shellb_bookmark_list_short \$@;) }"
eval "function ${shellb_func_bookmark_list_long}()  { (shellb_bookmark_list_long  \$@;) }"
eval "function ${shellb_func_bookmark_list_purge}() { (shellb_bookmark_list_purge \$@;) }"

# command functions
eval "function ${shellb_func_notepad_edit}()        { (shellb_notepad_edit      \"\$@\";) }"
eval "function ${shellb_func_notepad_show}()        { (shellb_notepad_show      \"\$@\";) }"
eval "function ${shellb_func_notepad_list}()        { (shellb_notepad_list      \"\$@\";) }"
eval "function ${shellb_func_notepad_del}()         { (shellb_notepad_del       \"\$@\";) }"
eval "function ${shellb_func_notepad_get}()         { (shellb_notepad_get       \"\$@\";) }"
eval "function ${shellb_func_notepad_calc}()        { (shellb_notepad_calc      \"\$@\";) }"
eval "function ${shellb_func_notepad_delall}()      { (shellb_notepad_delall    \"\$@\";) }"

###############################################
# completions for shortcuts
# (shortcuts prefixed with _)
###############################################
function shellb_completions_install() {
  complete -o nospace -F _shellb_bookmark_completions "${shellb_func_bookmark_set}"
  complete -F _shellb_bookmark_completions "${shellb_func_bookmark_del}"
  complete -F _shellb_bookmark_completions "${shellb_func_bookmark_get_short}"
  complete -F _shellb_bookmark_completions "${shellb_func_bookmark_get_long}"
  complete -F _shellb_bookmark_completions "${shellb_func_bookmark_goto}"
  complete -F _shellb_bookmark_completions "${shellb_func_bookmark_list_long}"
  complete -F _shellb_bookmark_completions "${shellb_func_bookmark_list_short}"
}

# install completions when we're sourced
shellb_completions_install