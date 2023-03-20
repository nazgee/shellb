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
_SHELLB_ALIASES=""

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
_SHELLB_CFG_COLOR_ROW=${_SHELLB_COLOR_GREEN}
_SHELLB_CFG_SYMBOL_CHECK=${_SHELLB_SYMBOL_CHECK}
_SHELLB_CFG_SYMBOL_CROSS=${_SHELLB_SYMBOL_CROSS}
_SHELLB_CFG_LOG_PREFIX="shellb | "
_SHELLB_CFG_PROTO="shellb://"
_SHELLB_CFG_NOTE_FILE="note.md"

_SHELLB_CFG_BOOKMARK_EXT="shellbbookmark"
_SHELLB_CFG_BOOKMARK_TAG_EXT="shellbbkmtag"

_SHELLB_CFG_COMMAND_EXT="shellbcommand"
_SHELLB_CFG_COMMAND_TAG_EXT="shellbcmdtag"

_SHELLB_CFG_HELP_RELOAD="invoke \"shellb reload-config\" to reload config from \"${_SHELLB_RC}\""

_SHELLB_CFG_RC_DEFAULT=\
'
# TODO add config here
'

###############################################
# init
###############################################
# save location of this script
_SHELLB_SOURCE_LOCATION="${BASH_SOURCE[0]}"

# check if required tools are available
[ -e "$(command -v uuidgen)" ] || _shellb_print_err "find not found. Please install uuid-runtime and ${_SHELLB_CFG_HELP_RELOAD}"
[ -e "$(command -v sed)" ] || _shellb_print_err "sed not found. Please install sed and ${_SHELLB_CFG_HELP_RELOAD}"
[ -e "$(command -v awk)" ] || _shellb_print_err "awk not found. Please install awk and ${_SHELLB_CFG_HELP_RELOAD}"
[ -e "$(command -v diff)" ] || _shellb_print_err "diff not found. Please install diffutils and ${_SHELLB_CFG_HELP_RELOAD}"

# provide default config it not present
[ -e "${_SHELLB_RC}" ] || _shellb_print_wrn_fail "creating default config: ${_SHELLB_RC}" \
  || echo "${_SHELLB_CFG_RC_DEFAULT}" > "${_SHELLB_RC}"

# install aliases
# shellcheck source=~/.shellbrc
source "${_SHELLB_RC}"

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
  # shellcheck source=./shellb.sh
  source "${_SHELLB_SOURCE_LOCATION}"
  _shellb_print_nfo "loaded (${_SHELLB_SOURCE_LOCATION} + ${_SHELLB_RC})"
}

function _shellb_aliases_compgen() {
  :
}

function _shellb_aliases_action() {
  _shellb_print_nfo "list of aliases defined in ${_SHELLB_RC}"
  for alias in ${_SHELLB_ALIASES}; do
    _shellb_print_nfo "$(type "${alias}" | sed -e "s/is aliased to \`/\t = /g; s/^/\t/; s/'$//;")"
  done
}

function shellb() {
  _shellb_print_nfo "$ shellb $*"
  [ -n "$1" ] || _shellb_print_err "no module specified" || return 1
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
      opts="${_SHELLB_MODULES[*]} help reload-config aliases"
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
# modules installation
###############################################
# shellcheck source=./core.sh
source "$(dirname "${_SHELLB_SOURCE_LOCATION}")/core.sh"
for module in "${_SHELLB_MODULES[@]}"; do
  _shellb_print_dbg "load ${module}"
  # shellcheck source=./bookmark.sh
  # shellcheck source=./note.sh
  # shellcheck source=./command.sh
  source "$(dirname "${_SHELLB_SOURCE_LOCATION}")/${module}.sh"
  _shellb_print_dbg "loaded ${module}"
done



###############################################
# completions installation
###############################################
function shellb_completions_install() {
  _SHELLB_ALIASES=$(cat "${_SHELLB_RC}" | grep -v "^[ \t]*#" | grep "^[ \t]*alias " | sed 's/[ /t]*alias[ /t]//' | sed 's/\([^=]*\)=.*/\1/')

  for alias in ${_SHELLB_ALIASES}; do
    _shellb_print_dbg "installing completion for alias: ${alias}"
    complete -F _complete_alias "${alias}"
  done

  complete -F _shellb shellb
}

# install completions when we're sourced
# shellcheck source=./complete_alias
_shellb_print_dbg "load complete_alias"
source "$(dirname "${_SHELLB_SOURCE_LOCATION})")/complete_alias"
_shellb_print_dbg "register completions"
shellb_completions_install
