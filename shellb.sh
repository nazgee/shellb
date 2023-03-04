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
_SHELLB_MODULES=("bookmark" "command" "note")

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
# TODO try not clashing with themes
_SHELLB_CFG_DEBUG=0
_SHELLB_CFG_COLOR_NFO=""
_SHELLB_CFG_COLOR_WRN=${_SHELLB_COLOR_YELLOW_B}
_SHELLB_CFG_COLOR_ERR=${_SHELLB_COLOR_RED_B}
_SHELLB_CFG_SYMBOL_CHECK=${_SHELLB_SYMBOL_CHECK}
_SHELLB_CFG_SYMBOL_CROSS=${_SHELLB_SYMBOL_CROSS}
_SHELLB_CFG_LOG_PREFIX="shellb | "
_SHELLB_CFG_SEPARATOR="------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
_SHELLB_CFG_NOTEPAD_TITLE_W=160
_SHELLB_CFG_PROTO="shellb://"
_SHELLB_CFG_NOTE_FILE="note.md"
_SHELLB_CFG_COMMAND_EXT="shellbcommand"

_SHELLB_CFG_HELP_RELOAD="invoke \"shellb reload-config\" to reload config from \"${_SHELLB_RC}\""

_SHELLB_CFG_RC_DEFAULT=\
'## notepad config
#  in debian distros, "editor" is a default cmdline editor
#  feel free to force "vim", "nano" or "whateveryouwant"
shellb_cfg_notepad_editor = editor

## core functions
shellb_func = shh
shellb_func_help = h

## primary/basic bookmark functions
shellb_func_bookmark_set = s
shellb_func_bookmark_del = r
shellb_func_bookmark_get = d
shellb_func_bookmark_goto = g
shellb_func_bookmark_list = sl
shellb_func_bookmark_list_goto = slg
shellb_func_bookmark_list_del = sld
shellb_func_bookmark_list_purge = slp
# secondary/advanced bookmark functions
shellb_func_bookmark_get_short = ds
shellb_func_bookmark_list_short = sls

## primary/basic notepad functions
shellb_func_notepad_edit = npe
shellb_func_notepad_show = nps
shellb_func_notepad_show_recurse = npsr
shellb_func_notepad_list = npl
shellb_func_notepad_list_edit = nple
shellb_func_notepad_list_show = npls
shellb_func_notepad_list_del = npld
shellb_func_notepad_del  = npd
shellb_func_notepad_delall  = npda
# secondary/advanced notepad functions
shellb_func_notepad_get  = npg

## primary/basic command functions
shellb_func_command_save_previous = cns
shellb_func_command_save_interactive = cnsi
shellb_func_command_list = cnl
shellb_func_command_list_exec = cnle
shellb_func_command_list_del = cnld
shellb_func_command_find = cnf
shellb_func_command_find_exec = cnfe
shellb_func_command_find_del = cnfd
# secondary/advanced command functions
'


###############################################
# init
###############################################
# save location of this script
_SHELLB_SOURCE_LOCATION="${BASH_SOURCE[0]}"

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
[ -e "$(command -v uuidgen)" ] || _shellb_print_err "find not found. Please install uuid-runtime and ${_SHELLB_CFG_HELP_RELOAD}"
[ -e "$(command -v sed)" ] || _shellb_print_err "sed not found. Please install sed and ${_SHELLB_CFG_HELP_RELOAD}"
[ -e "$(command -v awk)" ] || _shellb_print_err "awk not found. Please install awk and ${_SHELLB_CFG_HELP_RELOAD}"
[ -e "$(command -v diff)" ] || _shellb_print_err "diff not found. Please install diffutils and ${_SHELLB_CFG_HELP_RELOAD}"

# provide default config it not present
[ -e "${_SHELLB_RC}" ] || _shellb_print_wrn_fail "creating default config: ${_SHELLB_RC}" \
  || echo "${_SHELLB_CFG_RC_DEFAULT}" > "${_SHELLB_RC}"

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
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur} ))
  return 0
}


###############################################
# notepad completion functions
###############################################
#$1: comp_word
#$2: comp_cur
#$3: comp_prev
#$4: (comp_words)
function _shellb_notepad_list_opts() {
    local cur prev comp_word comp_words opts notepads

    comp_word="${1}"
    shift
    cur="${1}"
    shift
    prev="${1}"
    shift
    comp_words=("$@")
    cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete name or null
    prev="${COMP_WORDS[COMP_CWORD-1]}" # previous complete word, we're not interested, but it's here for reference

    notepads="$(_shellb_notepad_list_column "/")"
    for notepad in ${notepads}; do
      opts="${opts} $(realpath --relative-to "$(pwd)" "$(dirname "/${notepad}")") $(dirname "/${notepad}")"
    done

    echo "${opts}"
}

function _shellb_notepad_completions() {
  local opts
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()
  opts="$(_shellb_notepad_list_opts "${COMP_CWORD}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}" "${COMP_WORDS[@]}")"
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}

#$1: comp_word
#$2: comp_cur
#$3: comp_prev
#$4: (comp_words)
function _shellb_notepad_find_opts() {
    local cur prev comp_word comp_words opts notepads

    comp_word="${1}"
    shift
    cur="${1}"
    shift
    prev="${1}"
    shift
    comp_words=("$@")
    cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete name or null
    prev="${COMP_WORDS[COMP_CWORD-1]}" # previous complete word, we're not interested, but it's here for reference

    notepads="$(_shellb_notepad_list_column "/")"
    for notepad in ${notepads}; do
      opts="${opts} $(realpath --relative-to "$(pwd)" "$(dirname "/${notepad}")") $(dirname "/${notepad}")"
    done

    echo "${opts} /" # FIXME this is the only difference from _shellb_notepad_list_opts
}

function _shellb_notepad_completions_all() {
  local opts
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()
  opts="$(_shellb_notepad_find_opts "${COMP_CWORD}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}" "${COMP_WORDS[@]}")"
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}


############################################
# command completions
############################################
#$1: comp_word
#$2: comp_cur
#$3: comp_prev
#$4: (comp_words)
function _shellb_command_list_opts() {
    local cur prev comp_word comp_words opts commands

    comp_word="${1}"
    shift
    cur="${1}"
    shift
    prev="${1}"
    shift
    comp_words=("$@")
    cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete bookmark name or null
    prev="${COMP_WORDS[COMP_CWORD-1]}" # previous complete word, we're not interested, but it's here for reference

    commands="$(_shellb_command_list_column "/")"
    for command in ${commands}; do
      commands_dirs="${commands_dirs} $(dirname "/${command}")"
    done

    for command in ${commands_dirs}; do
      opts="${opts} $(realpath --relative-to "$(pwd)" "$(dirname "${command}")") $(dirname "${command}")"
    done

    echo "${opts}"
}

function _shellb_command_completions() {
  local opts
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()
  opts="$(_shellb_command_list_opts "${COMP_CWORD}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}" "${COMP_WORDS[@]}")"
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}

#$1: comp_word
#$2: comp_cur
#$3: comp_prev
#$4: (comp_words)
function _shellb_command_find_opts() {
    local cur prev comp_word comp_words opts commands

    comp_word="${1}"
    shift
    cur="${1}"
    shift
    prev="${1}"
    shift
    comp_words=("$@")
    cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete bookmark name or null
    prev="${COMP_WORDS[COMP_CWORD-1]}" # previous complete word, we're not interested, but it's here for reference

    commands="$(_shellb_command_find_column "/")"
    for command in ${commands}; do
      commands_dirs="${commands_dirs} $(dirname "/${command}")"
    done

    for command in ${commands_dirs}; do
      opts="${opts} $(realpath --relative-to "$(pwd)" "$(dirname "${command}")") $(dirname "${command}")"
    done

    echo "${opts} /"
}

function _shellb_command_completions_all() {
local opts
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()
  opts="$(_shellb_command_find_opts "${COMP_CWORD}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}" "${COMP_WORDS[@]}")"
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}
###############################################
# core functions
###############################################
# TODO implement
function shellb() {
  case ${1} in
    "bookmark")
      shift
      shellb_bookmark "$@"
      ;;
    "command")
      shift
      shellb_command "$@"
      ;;
    "notepad")
      shift
      (shellb_notepad "$@")
      ;;
    "help")
      shift
      shellb_help "$@"
      ;;
    "reload-config")
      shift
      source "${_SHELLB_SOURCE_LOCATION}"
      _shellb_print_nfo "loaded (${_SHELLB_SOURCE_LOCATION} + ${_SHELLB_RC})"
      ;;
    "module")
      shift
      _shellb_module_action "$@"
      ;;
    *)
      _shellb_print_err "unknown command: ${1}"
      ;;
  esac
}

function shellb_help() {
  _shellb_print_wrn_fail "not implemented yet ($*)"
}

function shellb_bookmark() {
  case ${1} in
    "set")
      shift
      (shellb_bookmark_set "$@")
      ;;
    "go")
      shift
      shellb_bookmark_goto "$@"
      ;;
    "get")
      shift
      (shellb_bookmark_get_long "$@")
      ;;
    "del")
      shift
      (shellb_bookmark_del "$@")
      ;;
    "list")
      shift
      (shellb_bookmark_list_long "$@")
      ;;
    *)
      _shellb_print_err "unknown command: ${1}"
      ;;
  esac
}

function shellb_notepad() {
  case ${1} in
    "edit")
      shift
      shellb_notepad_edit "$@"
      ;;
    "editlocal")
      shift
      shellb_notepad_edit "."
      ;;
    "show")
      shift
      shellb_notepad_list_show "/"
      ;;
    "showlocal")
      shift
      shellb_notepad_show "."
      ;;
    "showall")
      shift
      shellb_notepad_show_recurse "/"
      ;;
    "del")
      shift
      shellb_notepad_del "$@"
      ;;
    "dellocal")
      shift
      shellb_notepad_del "."
      ;;
    "delall")
      shift
      shellb_notepad_delall "$@"
      ;;
    "list")
      shift
      shellb_notepad_list "$@"
      ;;
    "listlocal")
      shift
      shellb_notepad_list "."
      ;;
    "listall")
      shift
      shellb_notepad_list "/"
      ;;
    *)
      _shellb_print_err "unknown command: ${1}"
      ;;
  esac
}

#"edit-local edit show-local show-all show del-local del-local del-all del list list-local list-all"

function shellb_command() {
  case ${1} in
    "saveinteractive")
      shift
      shellb_command_save_interactive "$@"
      ;;
    "saveprevious")
      shift
      shellb_command_save_previous "$@"
      ;;
    "execlocal")
      shift
      shellb_command_list_exec "."
      ;;
    "execglobal")
      shift
      shellb_command_find_exec "/"
      ;;
    "dellocal")
      shift
      shellb_command_list_del "."
      ;;
    "delglobal")
      shift
      shellb_command_find_del "/"
      ;;
    "listglobal")
      shift
      shellb_command_find "/"
      ;;
    "listlocal")
      shift
      shellb_command_list "."
      ;;
    "list")
      shift
      shellb_command_list "$@"
      ;;
    *)
      _shellb_print_err "unknown command: ${1}"
      ;;
  esac
}

#$1: comp_word
#$2: comp_cur
#$3: comp_prev
#$4: (comp_words)
function _shellb_bookmark_opts() {
  #_shellb_print_dbg "_shellb_bookmark_opts($*)"
  local opts comp_words comp_word comp_cur comp_prev
  local modifier_bookmarks="set go get del list"
  comp_word="${1}"
  shift
  comp_cur="${1}"
  shift
  comp_prev="${1}"
  shift
  comp_words=("$@")
  case ${comp_word} in
    1)
      _shellb_print_err "this should not happen"
      ;;
    2)
      opts="${modifier_bookmarks}"
      ;;
    3)
      case "${comp_words[2]}" in
        *)
                opts="$(_shellb_bookmarks_row)"
                ;;
      esac
      ;;
  esac

  echo "${opts}"
}

#$1: comp_word
#$2: comp_cur
#$3: comp_prev
#$4: (comp_words)
function _shellb_notepad_opts() {
  #_shellb_print_dbg "_shellb_notepad_opts($*)"
  local opts comp_words comp_word comp_cur comp_prev
  local modifier_notepads="editlocal edit showlocal showall show dellocal dellocal delall del list listlocal listall"
  comp_word="${1}"
  shift
  comp_cur="${1}"
  shift
  comp_prev="${1}"
  shift
  comp_words=("$@")
  case ${comp_word} in
    1)
      _shellb_print_err "this should not happen"
      ;;
    2)
      opts="${modifier_notepads}"
      ;;
    3)
      case "${comp_words[2]}" in
        *-global)
                opts="$(_shellb_notepad_find_opts "${comp_word}" "${cur}")"
                ;;
        *-local)
                opts="."
                ;;
        *-all)
                opts="/"
                ;;
        *)
                opts="$(_shellb_notepad_list_opts "${comp_word}" "${cur}")"
                ;;
      esac
      ;;
  esac

  echo "${opts}"
}

#$1: comp_word
#$2: comp_cur
#$3: comp_prev
#$4: (comp_words)
function _shellb_command_opts() {
  #_shellb_print_dbg "_shellb_command_opts($*)"
  local opts comp_words comp_word comp_cur comp_prev
  local modifier_commands="saveprevious saveinteractive execlocal execglobal dellocal delglobal listlocal listglobal list"
  comp_word="${1}"
  shift
  comp_cur="${1}"
  shift
  comp_prev="${1}"
  shift
  comp_words=("$@")
  case ${comp_word} in
    1)
      _shellb_print_err "this should not happen"
      ;;
    2)
      opts="${modifier_commands}"
      ;;
    3)
      case "${comp_words[2]}" in
        list)
          opts="$(_shellb_command_list_opts "${comp_word}" "${cur}" "${prev}" "${comp_words[@]}")"
          ;;
        find) # FIXME not used
          opts="$(_shellb_command_find_opts "${comp_word}" "${cur}" "${prev}" "${comp_words[@]}")"
          ;;
        *)
          opts=""
          ;;
      esac
      ;;
  esac

  echo "${opts}"
}

function _shellb_module_invoke() {
  local function_name module_name
  _shellb_print_dbg "_shellb_module_invoke($*)"

  function_name=$1
  shift
  module_name=$1
  shift

  eval "_shellb_${module_name}_${function_name} $*"
}

function _shellb_module_completion_opts() {
  _shellb_print_dbg "_shellb_module_completion_opts($*)"
  _shellb_module_invoke "completion_opts" "$@"
}

function _shellb_module_action() {
  _shellb_print_dbg "_shellb_module_action($*)"
  _shellb_module_invoke "action" "$@"
}

function _shellb_completions() {
  local cur prev opts notepads_column
  local modifiers="bookmark command notepad help reload-config module"

  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete bookmark name or null
  prev="${COMP_WORDS[COMP_CWORD-1]}" # previous complete word

  case ${COMP_CWORD} in
    1)
      opts="${modifiers}"
      ;;
    2)
      case "${COMP_WORDS[1]}" in
        bookmark)
          opts="$(_shellb_bookmark_opts "${COMP_CWORD}" "${cur}" "${prev}" "${COMP_WORDS[@]}")"
          ;;
        notepad)
          opts="$(_shellb_notepad_opts "${COMP_CWORD}" "${cur}" "${prev}" "${COMP_WORDS[@]}")"
          ;;
        command)
          opts="$(_shellb_command_opts "${COMP_CWORD}" "${cur}" "${prev}" "${COMP_WORDS[@]}")"
          ;;
        module)
          # convert modules array to space delimeted options string
          opts="${_SHELLB_MODULES[*]}"
          ;;
        *)
          ;;
        esac
        ;;
    *)
      case "${COMP_WORDS[1]}" in
        bookmark)
          opts="$(_shellb_bookmark_opts "${COMP_CWORD}" "${cur}" "${prev}" "${COMP_WORDS[@]}")"
          ;;
        notepad)
          opts="$(_shellb_notepad_opts "${COMP_CWORD}" "${cur}" "${prev}" "${COMP_WORDS[@]}")"
          ;;
        command)
          opts="$(_shellb_command_opts "${COMP_CWORD}" "${cur}" "${prev}" "${COMP_WORDS[@]}")"
          ;;
        module)
          local module comp_words comp_cword
          module="${COMP_WORDS[2]}"
          comp_cword=$(expr $COMP_CWORD - 2)
          comp_words=( ${COMP_WORDS[@]:2} )
          opts="$(_shellb_module_completion_opts "${module}" "${comp_cword}" "${comp_words[@]}")"
          ;;
      esac
      ;;
  esac

  # if cur is empty, we're completing bookmark name
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}

###############################################
# shortcuts
# (these are just aliases to the core functions)
###############################################
# note, that we invoke shellb_ functions in subshell (parenthesis operator),
# to avoid polluting current shell with any side effects of shellb_ functions

#core functions
eval "function ${shellb_func_help}()                { (shellb_help                \"\$@\";) }"

# primary/basic bookmark functions
eval "function ${shellb_func_bookmark_set}()        { (shellb_bookmark_set        \"\$@\";) }"
eval "function ${shellb_func_bookmark_del}()        { (shellb_bookmark_del        \"\$@\";) }"
eval "function ${shellb_func_bookmark_get}()        { (shellb_bookmark_get_long   \"\$@\";) }"
eval "function ${shellb_func_bookmark_goto}()       {  shellb_bookmark_goto       \"\$@\";  }" # no subshell, we need goto side effects
eval "function ${shellb_func_bookmark_list}()       { (shellb_bookmark_list_long  \"\$@\";) }"
eval "function ${shellb_func_bookmark_list_goto}()  {  shellb_bookmark_list_goto  \"\$@\";  }" # no subshell, we need goto side effects
eval "function ${shellb_func_bookmark_list_del}()   { (shellb_bookmark_list_del   \"\$@\";) }"
eval "function ${shellb_func_bookmark_list_purge}() { (shellb_bookmark_list_purge \"\$@\";) }"
# secondary/advanced bookmark functions
eval "function ${shellb_func_bookmark_get_short}()  { (shellb_bookmark_get_short  \"\$@\";) }"
eval "function ${shellb_func_bookmark_list_short}() { (shellb_bookmark_list_short \"\$@\";) }"

# primary/basic notepad functions
eval "function ${shellb_func_notepad_edit}()           { (shellb_notepad_edit         \"\$@\";) }"
eval "function ${shellb_func_notepad_show}()           { (shellb_notepad_show         \"\$@\";) }"
eval "function ${shellb_func_notepad_show_recurse}  () { (shellb_notepad_show_recurse \"\$@\";) }"
eval "function ${shellb_func_notepad_list}()           { (shellb_notepad_list         \"\$@\";) }"
eval "function ${shellb_func_notepad_list_edit}()      { (shellb_notepad_list_edit    \"\$@\";) }"
eval "function ${shellb_func_notepad_list_show}()      { (shellb_notepad_list_show    \"\$@\";) }"
eval "function ${shellb_func_notepad_list_del}()       { (shellb_notepad_list_del     \"\$@\";) }"
eval "function ${shellb_func_notepad_del}()            { (shellb_notepad_del          \"\$@\";) }"
eval "function ${shellb_func_notepad_delall}()         { (shellb_notepad_delall       \"\$@\";) }"
# secondary/advanced notepad functions
eval "function ${shellb_func_notepad_get}()            { (shellb_notepad_get          \"\$@\";) }"

# primary/basic command functions
eval "function ${shellb_func_command_save_previous}()    { (shellb_command_save_previous     \"\$@\";) }"
eval "function ${shellb_func_command_save_interactive}() { (shellb_command_save_interactive  \"\$@\";) }"
eval "function ${shellb_func_command_list}()             { (shellb_command_list              \"\$@\";) }"
eval "function ${shellb_func_command_list_exec}()        { (shellb_command_list_exec         \"\$@\";) }"
eval "function ${shellb_func_command_list_del}()         { (shellb_command_list_del          \"\$@\";) }"
eval "function ${shellb_func_command_find}()             { (shellb_command_find              \"\$@\";) }"
eval "function ${shellb_func_command_find_exec}()        { (shellb_command_find_exec         \"\$@\";) }"
eval "function ${shellb_func_command_find_del}()         { (shellb_command_find_del          \"\$@\";) }"

eval "function ${shellb_func}()                          { shellb                           \"\$@\"; }" # no subshell, we MAY need side effects

###############################################
# completions for shortcuts
# (shortcuts prefixed with _)
###############################################
function shellb_completions_install() {
  # bookmarks
  complete -o nospace -F _shellb_bookmark_completions "${shellb_func_bookmark_set}"
  complete -F _shellb_bookmark_completions            "${shellb_func_bookmark_del}"
  complete -F _shellb_bookmark_completions            "${shellb_func_bookmark_get}"
  complete -F _shellb_bookmark_completions            "${shellb_func_bookmark_get_short}"
  complete -F _shellb_bookmark_completions            "${shellb_func_bookmark_goto}"
  complete -F _shellb_bookmark_completions            "${shellb_func_bookmark_list}"
  complete -F _shellb_bookmark_completions            "${shellb_func_bookmark_list_short}"
  # notepads
  complete -F _shellb_notepad_completions             "${shellb_func_notepad_edit}"
  complete -F _shellb_notepad_completions             "${shellb_func_notepad_show}"
  complete -F _shellb_notepad_completions_all         "${shellb_func_notepad_show_recurse}"
  complete -F _shellb_notepad_completions_all         "${shellb_func_notepad_list}"
  complete -F _shellb_notepad_completions             "${shellb_func_notepad_del}"

  complete -F _shellb_command_completions             "${shellb_func_command_list}"
  complete -F _shellb_command_completions             "${shellb_func_command_list_exec}"
  complete -F _shellb_command_completions             "${shellb_func_command_list_del}"
  complete -F _shellb_command_completions_all         "${shellb_func_command_find}"
  complete -F _shellb_command_completions_all         "${shellb_func_command_find_exec}"
  complete -F _shellb_command_completions_all         "${shellb_func_command_find_del}"

  complete -F _shellb_completions                     "${shellb_func}"
  complete -F _shellb_completions                     shellb
}

# install completions when we're sourced
shellb_completions_install


if [[ -n "${SHELB_DEVEL_DIR}" ]]; then
  # shellcheck source=core.sh
  source core.sh
  # shellcheck source=bookmark.sh
  source bookmark.sh
  # shellcheck source=note.sh
  source note.sh
  # shellcheck source=command.sh
  source command.sh
else
  # shellcheck source=./core.sh
  source "$(dirname "${_SHELLB_SOURCE_LOCATION}")/core.sh"
  
  for module in "${_SHELLB_MODULES[@]}"; do
    _shellb_print_nfo "load ${module}"
    source "$(dirname "${_SHELLB_SOURCE_LOCATION}")/${module}.sh"
  done
fi
