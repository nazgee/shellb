# shellb - bookmarks, commands and notes manager for bash
# (c) 2023 Michal Stawinski, version 0.99
# Idea based on DirB (Directory Bookmarks for BASH (c) 2009-2010 by Ira Chayut)
#
# To integrate with your shell, save this shellb files <ANYWHERE>, and add the following line to ~/.bashrc:
#    source <ANYWHERE>/shellb.sh
#
# After restarting your terminal, try "shellb help" for help.


###############################################
# globals
###############################################
# paths
_SHELLB_RC="$(realpath -q ~/.shellbrc)"
_SHELLB_MODULES=("bookmark" "command" "note")
_SHELLB_ALIASES=""

# colors
_SHELLB_COLOR_NONE="\e[m"
_SHELLB_COLOR_GREEN="\e[00;32m"
_SHELLB_COLOR_RED="\e[00;31m"
_SHELLB_COLOR_RED_B="\e[01;31m"
_SHELLB_COLOR_YELLOW_B="\e[01;33m"

# config
# TODO try not clashing with themes
_SHELLB_CFG_DEBUG=0
_SHELLB_CFG_COLOR_NFO=""
_SHELLB_CFG_COLOR_WRN=${_SHELLB_COLOR_YELLOW_B}
_SHELLB_CFG_COLOR_ERR=${_SHELLB_COLOR_RED_B}

# Try to get colors from LS_COLORS. Use green if not available.
[[ -n "$LS_COLORS" ]] && _SHELLB_CFG_COLOR_DIR=$(echo "$LS_COLORS" | sed -n 's/.*\([:^]di=\)\([^:]*\).*/\2/p') && _SHELLB_CFG_COLOR_DIR="\e[${_SHELLB_CFG_COLOR_DIR}m" || _SHELLB_CFG_COLOR_DIR=${_SHELLB_COLOR_NONE}
[[ -n "$LS_COLORS" ]] && _SHELLB_CFG_COLOR_DIR_UNDER=$(echo "$LS_COLORS" | sed -n 's/.*\([:^]di=\)\([^:]*\).*/\2/p') && _SHELLB_CFG_COLOR_DIR_UNDER="\e[${_SHELLB_CFG_COLOR_DIR_UNDER};4m" || _SHELLB_CFG_COLOR_DIR_UNDER=${_SHELLB_COLOR_NONE}
[[ -n "$LS_COLORS" ]] && _SHELLB_CFG_COLOR_EXE=$(echo "$LS_COLORS" | sed -n 's/.*\([:^]ex=\)\([^:]*\).*/\2/p') && _SHELLB_CFG_COLOR_EXE="\e[${_SHELLB_CFG_COLOR_EXE}m" || _SHELLB_CFG_COLOR_EXE=${_SHELLB_COLOR_NONE}
[[ -n "$LS_COLORS" ]] && _SHELLB_CFG_COLOR_EXE_UNDER=$(echo "$LS_COLORS" | sed -n 's/.*\([:^]ex=\)\([^:]*\).*/\2/p') && _SHELLB_CFG_COLOR_EXE_UNDER="\e[${_SHELLB_CFG_COLOR_EXE_UNDER};4m" || _SHELLB_CFG_COLOR_EXE_UNDER=${_SHELLB_COLOR_NONE}
[[ -n "$LS_COLORS" ]] && _SHELLB_CFG_COLOR_LNK=$(echo "$LS_COLORS" | sed -n 's/.*\([:^]ln=\)\([^:]*\).*/\2/p') && _SHELLB_CFG_COLOR_LNK="\e[${_SHELLB_CFG_COLOR_LNK}m" || _SHELLB_CFG_COLOR_LNK=${_SHELLB_COLOR_GREEN}
[[ -n "$LS_COLORS" ]] && _SHELLB_CFG_COLOR_LNK_UNDER=$(echo "$LS_COLORS" | sed -n 's/.*\([:^]ln=\)\([^:]*\).*/\2/p') && _SHELLB_CFG_COLOR_LNK_UNDER="\e[${_SHELLB_CFG_COLOR_LNK_UNDER};4m" || _SHELLB_CFG_COLOR_LNK_UNDER=${_SHELLB_COLOR_GREEN}
[[ -n "$LS_COLORS" ]] && _SHELLB_CFG_COLOR_BAD=$(echo "$LS_COLORS" | sed -n 's/.*\([:^]or=\)\([^:]*\).*/\2/p') && _SHELLB_CFG_COLOR_BAD="\e[${_SHELLB_CFG_COLOR_BAD}m" || _SHELLB_CFG_COLOR_BAD=${_SHELLB_COLOR_RED}

# test colors by printing something using them
#echo -e "${_SHELLB_CFG_COLOR_DIR}_SHELLB_CFG_COLOR_DIR${_SHELLB_COLOR_NONE}"
#echo -e "${_SHELLB_CFG_COLOR_DIR_UNDER}_SHELLB_CFG_COLOR_DIR_UNDER${_SHELLB_COLOR_NONE}"
#echo -e "${_SHELLB_CFG_COLOR_LNK}_SHELLB_CFG_COLOR_LNK${_SHELLB_COLOR_NONE}"
#echo -e "${_SHELLB_CFG_COLOR_LNK_UNDER}_SHELLB_CFG_COLOR_LNK_UNDER${_SHELLB_COLOR_NONE}"
#echo -e "${_SHELLB_CFG_COLOR_EXE}_SHELLB_CFG_COLOR_EXE${_SHELLB_COLOR_NONE}"
#echo -e "${_SHELLB_CFG_COLOR_EXE_UNDER}_SHELLB_CFG_COLOR_EXE_UNDER${_SHELLB_COLOR_NONE}"
#echo -e "${_SHELLB_CFG_COLOR_BAD}_SHELLB_CFG_COLOR_BAD${_SHELLB_COLOR_NONE}"

_SHELLB_CFG_LOG_PREFIX="shellb | "
_SHELLB_CFG_PROTO="shellb://"
_SHELLB_CFG_NOTE_FILE="note.md"

_SHELLB_CFG_BOOKMARK_EXT="shellbbookmark"
_SHELLB_CFG_BOOKMARK_TAG_EXT="shellbbkmtag"
_SHELLB_CFG_COMMAND_EXT="shellbcommand"
_SHELLB_CFG_COMMAND_TAG_EXT="shellbcmdtag"

_SHELLB_CFG_RC_DEFAULT=\
"
##################### shellb config file ##################
# v 0.99

###################### general ############################
# Configure editor that will be used for \"shellb note edit\"
#
# In debian distros, \"editor\" is translated to user's
# preferred editor. Force sht like \"vim\" or \"nano\" here
# if that's not what you want.
export shellb_notepad_editor=editor

# Uncomment to enable prompt update with a bookmark that
# matches current working directory
# SHELLB_PROMPT_UPDATE=1

###################### aliases ############################
# Any alias here will have functional shell completion
# (TAB key arguments expansion). It is recommended to add
# aliases for shellb here, instead of ~/.bash_aliases.
#
# Change/add/remove aliases as desired, but avoid clashing
# with aliases/functions/binaries available on your system.
# (.e.g. \"ls\" or \"bg\" are not the best candidates)
#
# Names provided here by default should be safe/free
# on most of the systems, but double-check if it's the
# case for your system.

## 'core' aliases
alias shh='shellb'

## 'bookmark' aliases
alias bn='shellb bookmark new'
alias g='shellb bookmark go'
alias d='shellb bookmark del'
alias be='shellb bookmark edit'
alias bl='shellb bookmark list'
alias bp='shellb bookmark purge'

## 'notepad' aliases
alias npe='shellb note edit'
alias npea='shellb note edit /'
alias npl='shellb note list'
alias npd='shellb note del'
alias npc='shellb note cat'

## 'command' aliases
alias cmn='shellb command new'
alias cms='shellb command save'

alias cmr='shellb command run --current'
alias cmrr='shellb command run --recursive'
alias cmra='shellb command run --recursive /'

alias cmd='shellb command del --current'
alias cmdr='shellb command del --recursive'
alias cmda='shellb command del --recursive /'

alias cme='shellb command edit --current'
alias cmer='shellb command edit --recursive'
alias cmea='shellb command edit --recursive /'

alias cml='shellb command list --current'
alias cmlr='shellb command list --recursive'
alias cmla='shellb command list --recursive /'
"

###############################################
# init
###############################################
# save location of this script
_SHELLB_SOURCE_LOCATION="${BASH_SOURCE[0]}"

# check if required tools are available
_SHELLB_PROMPT_RELOAD="invoke \"shellb reload-config\" to reload config from \"${_SHELLB_RC}\""
[ -e "$(command -v uuidgen)" ] || _shellb_print_err "find not found. Please install uuid-runtime and ${_SHELLB_PROMPT_RELOAD}"
[ -e "$(command -v sed)" ] || _shellb_print_err "sed not found. Please install sed and ${_SHELLB_PROMPT_RELOAD}"
[ -e "$(command -v awk)" ] || _shellb_print_err "awk not found. Please install awk and ${_SHELLB_PROMPT_RELOAD}"
[ -e "$(command -v diff)" ] || _shellb_print_err "diff not found. Please install diffutils and ${_SHELLB_PROMPT_RELOAD}"

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

  function_name=$1
  shift
  module_name=$1
  shift

  "_shellb_${module_name}_${function_name}" "$@"
}

function _shellb_module_compgen() {
  _shellb_print_dbg "_shellb_module_compgen($*)"
  _shellb_module_invoke "compgen" "$@"
}

function _shellb_module_action() {
  _shellb_print_dbg "_shellb_module_action($*)"
  _shellb_module_invoke "action" "$@"
}

###############################################
# "help" compgen, action
###############################################

function _shellb_help_compgen() {
#

  _shellb_print_dbg "_shellb_help_compgen($*)"
  local opts cur
  cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete bookmark name or null
  # reset COMPREPLY, as it's global and may have been set in previous invocation
  COMPREPLY=()

  # by default: add space after completion. every module can override this
  compopt +o nospace

  case ${COMP_CWORD} in
    2)
      opts="${_SHELLB_MODULES[*]} reload-config aliases"
      ;;
    3)
      ;;
    *)
      ;;
  esac

  _shellb_print_dbg "_shellb_help_compgen() opts=${opts}"
  # if cur is empty, we're completing bookmark name
  #printf 'pre_%q_suf'  "${opts[@]}"

  COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
  return 0
}

function _shellb_help_action() {
  _shellb_print_dbg "_shellb_help_action($*)"
  local action="$1"
  shift

  case "${action}" in
    bookmark|command|note|aliases)
      _shellb_module_action "${action}" help "$1"
      ;;
    reload-config)
      echo "reload-config help"
      ;;
    *)
      echo "usage: shellb ACTION [options]"
      echo ""
      echo "shellb actions:"
      echo "    bookmark       Go to and manage bookmarked directories"
      echo "    command        Run and manage commands bound to a directory"
      echo "    note           Edit and manage notes bound to a directory"
      echo "    reload-config  Reload shellb config from ${_SHELLB_RC}"
      echo "    aliases        List shellb aliases defined in ${_SHELLB_RC}"
      echo ""
      echo "See \"shellb <action> help\" for more information on a specific action."
      ;;
  esac
}

###############################################
# "reload-config" compgen, action, help
###############################################
function _shellb_reload-config_compgen() {
  :
}

function _shellb_reload-config_action() {
  # shellcheck source=./shellb.sh
  source "${_SHELLB_SOURCE_LOCATION}"
  _shellb_print_nfo "loaded (${_SHELLB_SOURCE_LOCATION} + ${_SHELLB_RC})"
}
###############################################
# "aliases" compgen, action, help
###############################################
function _shellb_aliases_compgen() {
  local opts cur
  opts=("bookmark command note")
  cur="${COMP_WORDS[COMP_CWORD]}" # current incomplete bookmark name or null
  COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
}

function _shellb_aliases_action() {
  _shellb_print_dbg "_shellb_aliases_action($*)"
  local filter="${1}"
  local header
  local exit_code=1

  if [[ -n "${filter}" ]]; then
    header="List of \"${filter}\" aliases defined in ${_SHELLB_RC}"
  else
    header="List of aliases defined in ${_SHELLB_RC}"
  fi

  for alias in ${_SHELLB_ALIASES}; do
    local message
    message=$(type "${alias}" | sed -e "s/is aliased to \`/\t = /g; s/^/\t/; s/'$//;")
    if [[ -n "${filter}" ]]; then
      echo "${message}" | grep -q "${filter}" && {
         [ ${#header} -gt 0 ] && echo "${header}" && header=""
        echo "${message}"
        exit_code=0
      }
    else
      [ ${#header} -gt 0 ] && echo "${header}" && header=""
      echo "${message}"
      exit_code=0
    fi
  done

  return $exit_code
}

###############################################
# "shellb" compgen, action
###############################################

function shellb() {
  _shellb_print_nfo "$ shellb $*"
  [ -n "$1" ] || {
    _shellb_print_err "no action specified"
    _shellb_help_action "$@"
    return 1
  }
  _shellb_module_action "$@" || {
    _shellb_print_err "\"shellb $1\" failed"
    #_shellb_help_action "$1"
    return 1
  }
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

###############################################
# prompt integration
###############################################
# Backup the original PS1
[ -z "${_SHELLB_ORIGINAL_PS1}" ] && export _SHELLB_ORIGINAL_PS1="${PS1}"

# Function to update PS1 with the bookmark info
_shellb_update_ps1() {
  PS1="$(_shellb_pwd_bookmarks)${_SHELLB_ORIGINAL_PS1}"
}

# Update the PS1 every time a command is executed
[ ${SHELLB_PROMPT_UPDATE:-0} -eq 1 ] && PROMPT_COMMAND="_shellb_update_ps1; ${PROMPT_COMMAND}"
