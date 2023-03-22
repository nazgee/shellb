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

###############################################
# helper functions
###############################################
function _shellb_print_dbg() {
  [ "${_SHELLB_CFG_DEBUG}" -eq 1 ] && printf "${_SHELLB_CFG_LOG_PREFIX}DEBUG: ${_SHELLB_CFG_COLOR_NFO}%s${_SHELLB_COLOR_NONE}\n" "${1}" >&2
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

######### file operations #####################

function _shellb_core_remove() {
  _shellb_print_dbg "_shellb_core_remove($*)"
  local target
  target="${1}"
  [ -n "${target}" ] || _shellb_print_err "target can't be empty" || return 1
  [ -e "${target}" ] || _shellb_print_err "target doesn't exist" || return 1
  _shellb_core_is_path_below_and_owned "${target}" "${_SHELLB_DB}" || _shellb_print_err "target file ${target} is not below ${_SHELLB_DB}" || return 1
  rm "${target}" || _shellb_print_err "failed to remove ${target} file" || return 1
}

function _shellb_core_remove_dir() {
  _shellb_print_dbg "_shellb_core_remove($*)"
  local target
  target="${1}"
  [ -n "${target}" ] || _shellb_print_err "target can't be empty" || return 1
  [ -e "${target}" ] || _shellb_print_err "target doesn't exist" || return 1
  _shellb_core_is_path_below_and_owned "${target}" "${_SHELLB_DB}" || _shellb_print_err "target dir ${target} is not below ${_SHELLB_DB}" || return 1
  echo rm "${target}" -rf || _shellb_print_err "failed to remove ${target} dir" || return 1
}

######### interactive helpers #################

function _shellb_core_user_get_confirmation() {
  _shellb_print_dbg "_shellb_core_user_get_confirmation($*)"
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

# Return a number provided by the user between 1 and ${1}
# ${1} - max accepted number
function _shellb_core_user_get_number() {
  _shellb_print_dbg "_shellb_core_get_user_selection($*)"
  local -i selection
  local -i choices
  choices="${1}"
  read -r selection || return 1
  [ "${selection}" -gt 0 ] && [ "${selection}" -le "${choices}" ] || _shellb_print_err "unknown ID selected" || return 1
  echo "${selection}"
}

######### stdout filters ######################

# filter stdin and add prefix to each line
# will fail if line is empty
# ${1} - prefix
function _shellb_core_filter_add_prefix() {
  local prefix
  prefix="${1}"
  while read -r line; do
    [ -z "${line}" ] && return 1
    echo "${prefix}${line}"
  done
}

######### files list ##########################

# list all files in a given domain directory (just file names matching glob, return paths relative to the domain dir)
# ${1} - domain directory
# ${2} - file glob
# ${3} - user dir
function _shellb_core_ls_domainrel() {
  _shellb_print_dbg "_shellb_core_ls_domainrel($*)"
  local domain_dir user_dir file_glob
  domain_dir="${1}"
  file_glob="${2}"
  user_dir="${3}"
  [ -n "${domain_dir}" ] || _shellb_print_err "domain dir can't be empty" || return 1
  [ -n "${file_glob}" ] || file_glob="*"
  [ -n "${user_dir}" ] || user_dir="."
  user_dir="$(realpath -mq "${user_dir}")"
  find "${domain_dir}/${user_dir}" -maxdepth 1 -type f -name "${file_glob}" -printf "%P\n" 2>/dev/null
}

# list all files in a given domain directory (just file names matching glob, return absolute paths)
# ${1} - domain directory
# ${2} - file glob
# ${3} - user dir
function _shellb_core_ls_domainabs() {
  _shellb_print_dbg "_shellb_core_ls_domainabs($*)"
  local domain_dir user_dir file_glob
  domain_dir="${1}"
  file_glob="${2}"
  user_dir="$(realpath -mq "${3}")"

  _shellb_core_ls_domainrel "${domain_dir}" "${file_glob}" "${user_dir}" | _shellb_core_filter_add_prefix "${domain_dir}/${user_dir}/" | tr -s /
}

# list matching files in a given domain directory (just file names matching glob, return absolute paths)
# ${1} - domain directory
# ${2} - file glob
# ${3} - user dir
# ${4} - line to match
function _shellb_core_ls_domainabs_matching_whole_line() {
  _shellb_print_dbg "_shellb_core_ls_domainabs_matching_whole_line($*)"
  local domain_dir user_dir file_glob line_match
  domain_dir="${1}"
  file_glob="${2}"
  user_dir="$(realpath -mq "${3}")"
  line_match="${4}"
  [ -n "${domain_dir}" ] || _shellb_print_err "domain dir can't be empty" || return 1
  _shellb_core_is_path_below_and_owned "${domain_dir}/foo" "${domain_dir}" || _shellb_print_err "non-shellb domain=${domain_dir}" || return 1
  grep  -d skip -l --include="${file_glob}" -Fx "${line_match}" "$(realpath -mq "${domain_dir}/${user_dir}")/"* 2>/dev/null
}

######### files find ##########################

# list all files below a given domain directory (just file names matching glob, return paths relative to the domain dir)
# ${1} - domain directory
# ${2} - file glob
# ${3} - user dir
function _shellb_core_find_domainrel() {
  _shellb_print_dbg "_shellb_core_find_domainrel($*)"
  local domain_dir user_dir file_glob
  domain_dir="${1}"
  file_glob="${2}"
  user_dir="${3}"
  [ -n "${domain_dir}" ] || _shellb_print_err "domain dir can't be empty" || return 1
  [ -n "${file_glob}" ] || file_glob="*"
  [ -n "${user_dir}" ] || user_dir="."
  user_dir="$(realpath -mq "${user_dir}")"
  find "${domain_dir}/${user_dir}" -type f -name "${file_glob}" -printf "%P\n" 2>/dev/null
}

# list all files below a given domain directory (just file names matching glob, return absolute paths)
# ${1} - domain directory
# ${2} - file glob
# ${3} - user dir
function _shellb_core_find_domainabs() {
  _shellb_print_dbg "_shellb_core_find_domainabs($*)"
  local domain_dir user_dir file_glob
  domain_dir="${1}"
  file_glob="${2}"
  user_dir="$(realpath -mq "${3}")"

  _shellb_core_find_domainrel "${domain_dir}" "${file_glob}" "${user_dir}" | _shellb_core_filter_add_prefix "${domain_dir}/${user_dir}/" | tr -s /
}

######### files path helpers ##################

# fail if given path is not below given domain
# ${1} - path
# ${2} - domain
function _shellb_core_is_path_below() {
  local path domain
  path="${1}"
  domain="${2}"
  [ -n "${path}" ] || _shellb_print_err "path can't be empty" || return 1
  [ -n "${domain}" ] || _shellb_print_err "domain can't be empty" || return 1

  path=$(realpath -m "${path}")
  domain=$(realpath -m "${domain}")

  # make sure that path and dir are not the same
  [[ "$path" == "$domain" ]] && return 1

  # make sure that path is below dir
  [[ "${path}" == "${domain}"* ]] || return 1
}

# fail if given path is not below _SHELLB_DB
# fail if given path is not below given domain
# ${1} - path
# ${2} - domain
function _shellb_core_is_path_below_and_owned() {
  local path domain
  path="${1}"
  domain="${2}"
  _shellb_core_is_path_below "${path}" "${_SHELLB_DB}" || return 1
  _shellb_core_is_path_below "${path}" "${domain}" || return 1
}

# Returns absolute file or directory path, translated into a given domain.
# Fails only if domain is not below _SHELLB_DB
# ${1} - user dir or file
# ${2} - shellb domain directory
# FIXME: This function is slow. Check it's usage and optimize it
function _shellb_core_calc_user_to_domainabs() {
  _shellb_print_dbg "_shellb_core_calc_user_to_domainabs($*)"
  local file_user domain
  domain="${2}"
  _shellb_core_is_path_below_and_owned "${domain}/foo" "${domain}" || _shellb_print_err "non-shellb domain=${domain}" || return 1
  file_user="$(realpath -mq "${1}")"
  # remove duplicated slashes
  echo "${domain}/${file_user}" | tr -s /
}

# Translates absolute dir/file path into protocol path
# Translates absolute dir/file path into protocol path
# ${1} - absolute dir/file path (under domain)
# ${2} - domain
function _shellb_core_calc_domainabs_to_user() {
  _shellb_print_dbg "_shellb_core_calc_domainabs_to_user($*)"
  local path domain
  domain="${2}"
  _shellb_core_is_path_below_and_owned "${domain}/foo" "${domain}" || _shellb_print_err "non-shellb domain=${domain}" || return 1
  _shellb_core_is_path_below_and_owned "${1}" "${domain}" || _shellb_print_err "path=${1} is not below domain=${domain}" || return 1
  path=$(echo "${1#"$2"}" | tr -s /)
  echo "${path}"
}

# Translates absolute dir/file path into protocol path
# Translates absolute dir/file path into protocol path
# ${1} - absolute dir/file path (under domain)
# ${2} - domain
function _shellb_core_calc_proto_from_domainabs() {
  _shellb_print_dbg "_shellb_core_calc_proto_from_domainabs($*)"
  local path domain
  domain="${2}"
  _shellb_core_is_path_below_and_owned "${domain}/foo" "${domain}" || _shellb_print_err "non-shellb domain=${domain}" || return 1
  _shellb_core_is_path_below_and_owned "${1}/foo" "${domain}" || _shellb_print_err "path=${1} is not below domain=${domain}" || return 1
  path=$(echo "${1#"$2"}" | tr -s /)
  echo "${_SHELLB_CFG_PROTO}${path#"/"}"
}

# Translates user dir/file path into protocol path
# ${1} - user dir/file path
# ${2} - domain
function _shellb_core_calc_proto_from_user() {
  _shellb_print_dbg "_shellb_core_calc_proto_from_user($*)"
  local path domain
  path=$(realpath -eq "${1:-.}" | tr -s /)
  domain="${2}"
  _shellb_core_is_path_below_and_owned "${domain}/foo" "${domain}" || _shellb_print_err "non-shellb domain=${domain}" || return 1
  echo "${_SHELLB_CFG_PROTO}${path#"/"}"
}

function _shellb_core_completion_to_dir() {
  local completion
  completion="${1}"
  [ -d "${completion}" ] && echo "${completion}" && return 0
  dirname "${completion}"
}

######### compgen #############################

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
      files_in_domain_dir=$(_shellb_core_ls_domainrel "${domain}" "${resource_glob}" "$(realpath "${dir}")" 2>/dev/null)
      for file_in_domain_dir in ${files_in_domain_dir} ; do
        opts_resources="${opts_resources} $(echo "${dir}/${file_in_domain_dir}" | tr -s /)"
      done
    done
  fi

  # we want no space added after file/dir completion
  compopt -o nospace
  COMPREPLY=( $(compgen -o nospace -W "${opts_dirs} ${opts_file} ${opts_resources} ${extra_opts}" -- ${cur}) )
}

