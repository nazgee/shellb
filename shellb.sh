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
# core functions
###############################################

function _shellb_module_invoke() {
  local function_name module_name
  _shellb_print_dbg "_shellb_module_invoke($*)"

  function_name=$1
  shift
  module_name=$1
  shift

  eval "_shellb_${module_name}_${function_name} $*"
}

function _shellb_module_compgen() {
  _shellb_print_dbg "_shellb_module_compgen($*)"
  _shellb_module_invoke "compgen" "$@"
}

function _shellb_module_action() {
  _shellb_print_dbg "_shellb_module_action($*)"
  _shellb_module_invoke "action" "$@"
}

function _shellb_help_compgen() {
  _shellb_print_err "help compgen not implemented yet"
}

function _shellb_help_action() {
  _shellb_print_err "help action implemented yet"
}

function _shellb_reload-config_compgen() {
  :
}

function _shellb_reload-config_action() {
  source "${_SHELLB_SOURCE_LOCATION}"
  _shellb_print_nfo "loaded (${_SHELLB_SOURCE_LOCATION} + ${_SHELLB_RC})"
}

function shellb() {
  _shellb_print_dbg "shellb($*)"
  _shellb_module_action "$@"
}

function _shellb() {
  _shellb_print_dbg "_shellb($*)"
  local opts cur
  cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete bookmark name or null
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()

  # by default: add space after completion. every module can override this
  compopt +o nospace

  case ${COMP_CWORD} in
    1)
      opts="${_SHELLB_MODULES[*]} help reload-config"
      ;;
    *)
      _shellb_print_dbg "calling module compgen"
      _shellb_module_compgen "${COMP_WORDS[1]}"
      return 0
      ;;
  esac

  _shellb_print_dbg "_shellb() opts=${opts}"
  # if cur is empty, we're completing bookmark name
  #printf 'pre_%q_suf'  "${opts[@]}"

  COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
  return 0
}

###############################################
# completions for shortcuts
# (shortcuts prefixed with _)
###############################################
function shellb_completions_install() {
  # TODO fixit

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

  complete -F _shellb                                 "${shellb_func}"
  complete -F _shellb                                   shellb
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
