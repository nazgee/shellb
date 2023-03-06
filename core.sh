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

_SHELLB_DB="$(realpath -q ~/.shellB)"
_SHELLB_COLUMN_SEPARATOR=" | "

###############################################
# helper functions
###############################################
function _shellb_print_dbg() {
  [ ${_SHELLB_CFG_DEBUG} -eq 1 ] && printf "${_SHELLB_CFG_LOG_PREFIX}DEBUG: ${_SHELLB_CFG_COLOR_NFO}%s${_SHELLB_COLOR_NONE}\n" "${1}" >&2
}

function _shellb_print_nfo() {
  printf "${_SHELLB_CFG_LOG_PREFIX}${_SHELLB_CFG_COLOR_NFO}%s${_SHELLB_COLOR_NONE}\n" "${1}"
}

function _shellb_print_wrn() {
  printf "${_SHELLB_CFG_LOG_PREFIX}${_SHELLB_CFG_COLOR_WRN}%s${_SHELLB_COLOR_NONE}\n" "${1}"
}

function _shellb_print_wrn_fail() {
  _shellb_print_wrn "${1}" >&2
  # for failures chaining
  return 1
}

function _shellb_print_err() {
  printf "${_SHELLB_CFG_LOG_PREFIX}${_SHELLB_CFG_COLOR_ERR}%s${_SHELLB_COLOR_NONE}\n" "${1}" >&2
  # for failures chaining
  return 1
}

function _shellb_core_get_user_confirmation() {
  _shellb_print_dbg "_shellb_core_get_user_confirmation($*)"
  local question reply
  question="${1}"
  _shellb_print_wrn "${question} [Y/n]"
  read reply || return 1

  case $reply in
      ''|'y'|'Y')
        return 0
        ;;
      'n'|'N'|*)
        return 1
        ;;
  esac
}

function _shellb_core_domain_files_ls() {
  _shellb_print_dbg "_shellb_core_domain_files_ls($*)"
  local domain_dir user_dir file_glob
  domain_dir="${1}"
  file_glob="${2}"
  user_dir="${3}"
  [ -n "${domain_dir}" ] || _shellb_print_err "domain dir can't be empty" || return 1
  [ -n "${file_glob}" ] || file_glob="*"
  [ -n "${user_dir}" ] || user_dir="."
  find "${domain_dir}/${user_dir}" -maxdepth 1 -type f -name "${file_glob}" -printf "%P\n"
}

function _shellb_core_domain_files_find() {
  _shellb_print_dbg "_shellb_core_domain_dirs_list($*)"
  local domain_dir user_dir file_glob
  domain_dir="${1}"
  file_glob="${2}"
  user_dir="${3}"
  [ -n "${domain_dir}" ] || _shellb_print_err "domain dir can't be empty" || return 1
  [ -n "${file_glob}" ] || file_glob="*"
  [ -n "${user_dir}" ] || user_dir="."
  find "${domain_dir}/${user_dir}" -type f -name "${file_glob}" -printf "%P\n"
}

# filter row from stdin
# ${1} - row number (first row is 1)
function _shellb_core_filter_row() {
  _shellb_print_dbg "_shellb_core_get_row($*)"
  local i=1
  while read -r line; do
      if [ $i -eq $1 ]; then
          echo "$line"
      fi
      i=$((i+1))
  done
}

# filter column from stdin
# ${1} - column number
function _shellb_core_filter_column() {
  while read -r line; do
      echo "$line" | awk -F' \\| ' "{print \$${1}}"
  done
}

# trims and compresses whitespaces in a given string
# ${1} string to trim and compress
function _shellb_core_string_trim_and_compress() {
  echo "${1}" | awk '{$1=$1};1'
}

# trims whitespaces in a given string
# ${1} string to trim
function _shellb_core_string_trim() {
  echo "${1}" | xargs
}

# Returns absolute file or directory path, translated into a given domain. Always succeeds.
# ${1} - user dir or file
# ${2} - shellb domain directory
function _shellb_core_calc_domain_from_user() {
  _shellb_print_dbg "_shellb_core_calc_domain_from_user($*)"
  local file_user domain
  file_user="$(realpath -mq "${1}")"
  domain="${2}"
  echo "${domain}/${file_user}" | tr -s /
}

# Returns absolute file path translated into a given domain.
# Will fail if file does not exist in the domain
# ${1} - user filename
# ${2} - shellb domain directory
function _shellb_core_file_get_domain_from_user() {
  _shellb_print_dbg "_shellb_core_file_get_domain_from_user($*)"
  local in_domain
  in_domain=$(_shellb_core_calc_domain_from_user "${1}" "${2}")
  [ -f "${in_domain}" ] || _shellb_print_err "file '${in_domain}' does not exist in \"${2}\" domain" || return 1
  echo "${in_domain}"
}

# Returns absolute directory path translated into a given domain.
# Will fail if directory does not exist in the domain.
# ${1} - user dirname
# ${2} - shellb domain directory
function _shellb_core_dir_get_domain_from_user() {
  _shellb_print_dbg "_shellb_core_file_get_domain_from_user($*)"
  local in_domain
  in_domain=$(_shellb_core_calc_domain_from_user "${1}" "${2}")
  [ -d "${in_domain}" ] || _shellb_print_err "directory '${in_domain}' does not exist in \"${2}\" domain" || return 1
  echo "${in_domain}"
}

# Translates absolute dir/file path into protocol path
# ${1} - absolute dir/file path (under domain)
# ${2} - domain
function _shellb_core_calc_domainrel_from_abs() {
  local path
  path=$(echo "${1#"$2"}" | tr -s /)
  echo "${_SHELLB_CFG_PROTO}${path#"/"}"
}

# return 0 if content is same as file
# ${1} - content to test
# ${2} - file to test against
function _shellb_core_is_same_as_file() {
  _shellb_print_dbg "_shellb_core_is_same_as_file(${1})"
  local content file
  content="${1}"
  file="${2}"
  if (echo "${content}" | diff -q - "${file}" > /dev/null) ; then
    return 0
  else
    return 1
  fi
}

function _shellb_core_completion_to_dir() {
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
# When non-empty $3 will be provided, non-exisiting shelb resource will be listed
# under the directory of a currently shown completion, with a name given by $1
# e.g. for "../" completion and $1="aaaaaaaaaa.md":
#    ../zzzzzz/    ../foo.md     ../aaaaaaaaaa.md
#    ../bar.md     ../dirb/
# - existing user dirs:         "../zzzzzzz/" "../dirb/"
# - existing shellb resources:  "../bar.md"   "../foo.md"
# - non-existing shellb resource: "../aaaaaaaaaa.md"
#
# $1 - shellb domain
# $2 - optional, shellb-resource glob
# $3 - optional, name of a non-existing shellb-resource
# $4 - optional, additional completions to be added to the list
function _shellb_core_compgen() {
  _shellb_print_dbg "_shellb_core_compgen($*)"

  local domain resource_glob extra_file extra_opts comp_cword comp_words comp_cur
  local opts_dirs opts_file opts_resources

  domain="${1}"
  resource_glob="${2}"
  extra_file="${3}"
  extra_opts="${4}"
  comp_cword="${COMP_CWORD}"
  comp_words=( ${COMP_WORDS[@]} )
  comp_cur="${comp_words[$comp_cword]}"

  if [ -n "${extra_file}" ]; then
    if realpath -eq "${cur:-./}" > /dev/null ; then
      # remove potential double slashes
      opts_file="$(echo "${cur:-./}/${extra_file}" | tr -s /)"
    else
      opts_file="$(dirname "${cur:-./}")/${extra_file}"
    fi
  fi

  # get all directories and files in direcotry of current word
  opts_dirs=$(compgen -d -S '/' -- "${cur:-.}")

  # look for resources in domain if resource_glob is provided
  if [ -n "${resource_glob}" ]; then
    local comp_cur_dir
    # translate current completion to a directory
    comp_cur_dir=$(_shellb_core_completion_to_dir "${comp_cur}")

    # check what files are in _SHELLB_DB_NOTES for current completion word
    # and for all dir-based completions
    for dir in ${opts_dirs} ${comp_cur_dir} ; do
      files_in_domain_dir=$(_shellb_core_domain_files_ls "${domain}" "${resource_glob}" "$(realpath "${dir}")" 2>/dev/null)
      for file_in_domain_dir in ${files_in_domain_dir} ; do
        opts_resources="${opts_resources} $(echo "${dir}/${file_in_domain_dir}" | tr -s /)"
      done
    done
  fi

  # we want no space added after file/dir completion
  compopt -o nospace
  COMPREPLY=( $(compgen -o nospace -W "${opts_dirs} ${opts_file} ${opts_resources} ${extra_opts}" -- ${cur}) )
}

