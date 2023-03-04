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

echo "core loading..."

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

function _shellb_core_domain_files_ls() {
  _shellb_print_dbg "_shellb_core_domain_files_list($*)"
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

function _shellb_core_get_user_selection_column() {
  local list column target
  list="${1}"
  column="${2}"
  read target || return 1

  case $target in
      ''|*[!0-9]*)
        echo "${target}"
        ;;
      *)
        target=$(echo "${list}" | sed -n "${target}p" | xargs | awk -F' | \\| ' "{print \$${column}}")
        echo "${target}"
  esac
}

function _shellb_core_get_user_selection_whole() {
  local list column target
  list="${1}"
  read target || return 1

  case $target in
      ''|*[!0-9]*)
        echo "${target}"
        ;;
      *)
        target=$(echo "${list}" | sed -n "${target}p" | sed 's/[[:space:]]*[0-9]*)[[:space:]]//')
        echo "${target}"
  esac
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

# ${1} - shellb domain directory
# ${2} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_calc_absdir() {
  _shellb_print_dbg "_shellb_core_calc_absdir($*)"
  [ -n "${1}" ] || _shellb_print_err "domain dir can't be empty" || return 1
  echo "${1}$(realpath -m "${2:-.}")"
}

# ${1} - filename
# ${2} - shellb domain directory
# ${3} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_calc_absfile() {
  _shellb_print_dbg "_shellb_core_calc_file($*)"
  [ -n "${1}" ] || _shellb_print_err "file name can't be empty" || return 1
  [ -n "${2}" ] || _shellb_print_err "domain dir can't be empty" || return 1
  echo "$(_shellb_core_calc_absdir "${2}" "${3:-.}")/${1}"
}

# ${1} - filename
# ${2} - shellb domain directory
function _shellb_core_calc_domainfile() {
  _shellb_print_dbg "_shellb_core_calc_domainfile($*)"
  local file domain
  file="${1}"
  domain="${2}"
  realpath -m --relative-to "${domain}" "${file}"
}

# ${1} - shellb domain directory
# ${2} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_calc_domaindir() {
  _shellb_print_dbg "_shellb_core_calc_domaindir($*)"
  local dir domain
  domain="${1}"
  dir="${2}"
  if [[ "$(realpath -m "${dir}")" = "$(realpath -m "${domain}")" ]]; then
    echo ""
  else
    realpath -m --relative-to "${domain}" "${dir}"
  fi
}

# TODO remove
# ${1} - shellb domain directory
# ${2} - files to look for
# ${3} - printout suffix
# ${4} - find options
# ${5} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_find_with_suffix() {
  local user_dir domain_absdir items_seen results_separator target_glob
  domain_absdir="${1}"
  target_glob="${2}"
  results_separator="${3}"
  find_options="${4}"
  user_dir="${5}"

  [ -n "${user_dir}" ] || _shellb_print_err "_shellb_core_find_with_suffix, search top not given" || return 1

  domain_absdir=$(_shellb_core_calc_absdir "${domain_absdir}" "${user_dir}")
  # if directory does not exist, definitely no results are available -- bail out early
  # to avoid errors from find not being able to start searching
  [ -d "${domain_absdir}" ] || return 1

  items_seen=0
  while read -r item
  do
    items_seen=1
    local shellb_file
    shellb_file=$(_shellb_core_calc_domainfile "${item}" "${domain_absdir}")
    # display only the part of the path that is below domain_absdir directory
    printf "%s%b" "${shellb_file}" "${results_separator}"
  done < <(find "${domain_absdir}" ${find_options} -name "${target_glob}" 2>/dev/null || _shellb_print_err "_shellb_core_find_with_suffix, is ${domain_absdir} accessible?") || return 1

  # if no items seen, return error
  [ "${items_seen}" -eq 1 ] || return 1
  return 0
}

# TODO remove
# ${1} - shellb domain directory
# ${2} - files to look for
# ${3} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_find_as_row() {
  _shellb_core_find_with_suffix "${1}" "${2}"   " "   "-mindepth 1"   "${3}"
}

# TODO remove
# ${1} - shellb domain directory
# ${2} - files to look for
# ${3} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_find_as_column() {
  _shellb_core_find_with_suffix "${1}" "${2}"   "\n"   "-mindepth 1"   "${3}"
}

# TODO remove
# ${1} - shellb domain directory
# ${2} - files to look for
# ${3} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_list_as_row() {
  _shellb_core_find_with_suffix "${1}" "${2}"   " "   "-mindepth 1 -maxdepth 1"   "${3}"
}

# TODO remove
# ${1} - shellb domain directory
# ${2} - files to look for
# ${3} - userspace directory (optional, if not provided, current directory is used)
function _shellb_core_list_as_column() {
  _shellb_core_find_with_suffix "${1}" "${2}"   "\n"   "-mindepth 1 -maxdepth 1"   "${3}"
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

# Return column of files below directory matching content
# ${1} - content to test
# ${2} - directory to start searching from
# ${3} - files glob, optional (by default test each file_
function _shellb_core_find_files_matching_content_as_column() {
  local content search_top search_glob seen
  content="${1}"
  search_top="${2}"
  search_glob="${3}"
  seen=0

  while read -r file_to_test
  do
    _shellb_core_is_same_as_file "${content}" "${search_top}/${file_to_test}" && realpath -q "${search_top}/${file_to_test}" && seen=1
  done < <(_shellb_core_find_as_column "${search_top}" "${search_glob:-*}" "/")

  [ "${seen}" -eq 1 ] || return 1
  return 0
}

# Return column of files in given directory matching content
# ${1} - content to test
# ${2} - directory to start searching from
# ${3} - files glob, optional (by default test each file_
function _shellb_core_list_files_matching_content_as_column() {
  local content search_top search_glob
  content="${1}"
  search_top="${2}"
  search_glob="${3}"

  while read -r file_to_test
  do
    _shellb_core_is_same_as_file "${content}" "${search_top}/${file_to_test}" && realpath -q "${search_top}/${file_to_test}"
  done < <(_shellb_core_list_as_column "${search_top}" "${search_glob:-*}" "/")
}
