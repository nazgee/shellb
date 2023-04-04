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

_SHELLB_DB="$(realpath -q ~/.shellb)"

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
  [ -e "${target}" ] || _shellb_print_err "target \"${target}\" doesn't exist" || return 1
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

######### filters #############################

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

function _shellb_core_calc_common_part_sticky() {
  local prev_target target previous_ref_target
  prev_target="${1}"
  target="${2}"
  previous_ref_target="${3}"

  if [[ -n "${prev_target}" && "${target}" == "${prev_target}"* ]]; then
    echo "${prev_target}"
  elif [[ -n "${previous_ref_target}" && "${target}" == "${previous_ref_target}"* ]]; then
    echo "${previous_ref_target}"
  else
    echo ""
  fi
}

function _shellb_core_calc_common_part() {
  local curr="$1"
  local prev="$2"
  local next="$3"
  local common_prev=""
  local common_next=""

  for ((i=0; i<${#curr} && i<${#prev}; i++)); do
    if [[ "${curr:i:1}" == "${prev:i:1}" ]]; then
      common_prev="${common_prev}${curr:i:1}"
    else
      break
    fi
  done

  for ((i=0; i<${#curr} && i<${#next}; i++)); do
    if [[ "${curr:i:1}" == "${next:i:1}" ]]; then
      common_next="${common_next}${curr:i:1}"
    else
      break
    fi
  done

  if [[ ${#common_prev} -gt ${#common_next} ]]; then
    echo "$common_prev"
  else
    echo "$common_next"
  fi
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

# Translates absolute dir/file of shellb domain resource path to user path
# ${1} - absolute dir/file path (user dir or file)
# ${2} - domain
function _shellb_core_calc_domainabs_to_user() {
  _shellb_print_dbg "_shellb_core_calc_domainabs_to_user($*)"
  local path domain
  domain="${2}"
  _shellb_core_is_path_below_and_owned "${domain}/foo" "${domain}" || _shellb_print_err "non-shellb domain=${domain}" || return 1
  _shellb_core_is_path_below_and_owned "${1}/foo" "${domain}" || _shellb_print_err "path=${1} is not below domain=${domain}" || return 1
  path=$(echo "/${1#"$2"}" | tr -s /)
  echo "${path}"
}

# Translates user dir/file path into protocol shellb domain resource path
# ${1} - absolute dir/file path (under shellb domain)
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

# Interactively filter provided data until single line is left.
# Assign filtered result into variable provided as second arg.
# ${1} - multline data to filter
# ${2} - output variable name (matched string)
# ${3} - output variable name (matched string index)
# ${4} - instructions string
# ${5} - prompt string to show while still searching
# ${6} - prompt string to show when found
# return 0 if matched and confirmed with ENTER, non-zero if interrupted with CTRL+c or ESC
function _shellb_core_interactive_filter() {
  local search_term=""
  local exit_code=1
  local input_data="$1"
  local -n _shellb_core_interactive_filter_output=$2
  local -n _shellb_core_interactive_filter_output_index=$3
  local instructions="$4"
  local prompt_search="$5"
  local prompt_confirm="$6"
  local interrupted=0
  local resized=0

  # if there is only one line, return it
  # but succeed only if it is not empty
  if [[ $(echo "$input_data" | wc -l) -eq 1 ]]; then
    _shellb_core_interactive_filter_output="$input_data"
    _shellb_core_interactive_filter_output_index=1
    if [[ ${#_shellb_core_interactive_filter_output} -gt 0 ]]; then
      return 0
    else
      return 1
    fi
  fi

  # Save the current terminal settings
  local _shellb_core_interactive_filter_stty_settings
  _shellb_core_interactive_filter_stty_settings=$(stty -g)

  tput smcup # so we don't pollute scrollback too much

  function _shellb_core_interactive_filter_stty_default() {
    stty "$_shellb_core_interactive_filter_stty_settings"
  }

  function _shellb_core_interactive_filter_stty_custom() {
    stty -echo raw
  }

  function _shellb_core_interactive_filter_trap() {
    interrupted=1
  }

  function _shellb_core_interactive_filter_resize_trap() {
    resized=1
  }

  # returns:
  #  0 - if single command is matched
  #  1 - if multiple commands are matched
  #  2 - if no commands are matched
  function _shellb_core_interactive_filter_grep() {
    # shellcheck disable=SC2206
    local search_terms=(${1})
    local filtered="$input_data"
    local matched_lines

    for term in "${search_terms[@]}"; do
      filtered=$(echo "$filtered" | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' |  grep -i --color=always "$term")
    done

    matched_lines=$(echo "$filtered" | wc -l)
    if [[ ${matched_lines} -gt 1 ]]; then
      echo "${filtered}"
      return 1
    else
      # check if matched line is empty (no matches) or not (single match)
      if [[ ${#filtered} -gt 0 ]]; then
        echo "$filtered"
        return 0
      else
        return 2
      fi
    fi
  }

  # returns:
  #  0 - if single command is matched
  #  1 - if multiple commands are matched
  #  2 - if no commands are matched
  function _shellb_core_interactive_filter_update_screen() {
    local -n filtered
    filtered="$1"
    shift
    local search_term="$1"
    local prompt_search="$2"
    local prompt_confirm="$3"
    local terminal_rows
    local terminal_cols
    local matched=0

    # Get terminal dimensions
    terminal_rows=$(tput lines)
    terminal_cols=$(tput cols)

    # get the filtered lines
    filtered=$(_shellb_core_interactive_filter_grep "$search_term")
    matched=$?

    # do not print anything if we got not matches (exit immediately)
    [ ${matched} -eq 2 ] && return 2

    tput civis # hide the cursor, so it doesn't flicker
    tput cup 0 0 # move cursor to top left, so we can redraw the screen
    # print padding lines to clear the screen
    for ((i=0; i<((terminal_rows - $(echo "$filtered" | wc -l) ) - 2); i++)); do
      printf "%-${terminal_cols}s\n" "."
    done
    # print filtered lines, but pad them to the terminal width (to clear old lines)
    while IFS= read -r line; do
      printf "%-${terminal_cols}s\n" "$line"
    done <<< "${filtered}"

    printf "%-${terminal_cols}s\n" " "
    printf "%-${terminal_cols}s\n" " "
    tput cup $((terminal_rows - 2)) 0 # move cursor to the bottom line
    echo "$instructions"
    local final_promopt
    if [[ $matched -eq 0 ]]; then
      printf "%s %s (press ENTER to confirm)" "$prompt_search" "$search_term"
    else
      printf "%s %s" "$prompt_search" "$search_term"
    fi

    # Show the cursor
    tput cnorm
    return ${matched}
  }

  # Catch signals to restore terminal settings before exiting
  trap _shellb_core_interactive_filter_trap INT
  trap _shellb_core_interactive_filter_resize_trap WINCH

  local input
  while [[ $interrupted -eq 0 ]]; do
    local matched
    _shellb_core_interactive_filter_stty_default # default key/signals handling (so echo/print works normally)
    _shellb_core_interactive_filter_update_screen _shellb_core_interactive_filter_output "$search_term" "$prompt_search" "$prompt_confirm"
    matched=$?
    if [[ ${matched} -eq 2 ]]; then
      [ ${#search_term} -gt 0 ] && search_term="${search_term:0:-1}"
      _shellb_core_interactive_filter_update_screen _shellb_core_interactive_filter_output "$search_term" "$prompt_search" "$prompt_confirm"
      matched=$?
    fi
    _shellb_core_interactive_filter_stty_custom # custom key/signals handling (so we can read single chars)

    while [[ ${interrupted} -eq 0 ]]; do
      # we use a small timeout, so we can react to ctrl+c telling us to quit
      # (users have a tendency to use it, when they want to abort a command)
      IFS= read -r -n1 -t 0.1 input && break
      # stop waiting for key press if we got a resize signal
      [ ${resized} -eq 1 ] && break
    done

    # if we got a resize signal, redraw the screen immediately, and go back to reading input
    [ ${resized} -eq 1 ] && {
      resized=0
      continue
    }

    # if we got an interrupt signal, exit immediately
    [ ${interrupted} -eq 1 ] && {
      break
    }

    # if we're not interrupted, we can handle the input
    if [[ "${input}" == $'\x1b' ]]; then # handle ESC key
      break
    elif [[ "${input}" == $'\x7f' ]]; then # handle backspace key
      [ ${#search_term} -gt 0 ] && search_term="${search_term:0:-1}"
    elif [[ "${input}" == '' ]]; then # handle ENTER key
      if [[ $matched -eq 0 ]]; then
        exit_code=0
        break
      fi
    else
      search_term+="${input}"
    fi
   done
  _shellb_core_interactive_filter_stty_default # default key/signals handling (so echo/print works normally)

  # Remove the trap by resetting it to its default behavior
  trap - INT
  trap - WINCH
  tput rmcup

  # strip out colors before searching for matched row
  _shellb_core_interactive_filter_output=$(echo "$_shellb_core_interactive_filter_output" | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' )
  input_data=$(echo "$input_data" | sed 's/\x1B[@A-Z\\\]^_]\|\x1B\[[0-9:;<=>?]*[-!"#$%&'"'"'()*+,.\/]*[][\\@A-Z^_`a-z{|}~]//g' )

  # get the index of the selected line
  if [[ $exit_code -eq 0 ]]; then
    local row_number=1
    while IFS= read -r line; do
      [ "$line" == "$_shellb_core_interactive_filter_output" ] && {
        _shellb_core_interactive_filter_output_index=$row_number
        exit_code=0
        break
      }
      row_number=$((row_number + 1))
    done <<< "$input_data"
  fi

  return $exit_code
}

function shellb_foo() {
  local shellb_foo_filtered_line shellb_foo_filtered_line_index
  _shellb_print_dbg "shellb_foo($*)"
  _shellb_foo "select bookmark to goto" shellb_foo_filtered_line shellb_foo_filtered_line_index "${@}" || return 1
  echo "${shellb_foo_filtered_line}"
  echo "${shellb_foo_filtered_line_index}"
}

function _shellb_foo() {
  _shellb_print_dbg "_shellb_foo($*)"
  local prompt="${1}"
  shift
  local -n _shellb_foo_filtered_line=$1
  shift
  local -n _shellb_foo_filtered_line_index=$1
  shift
  local -a _shellb_foo_bookmarks
  local -a _shellb_foo_bookmarks_lines
  local bookmarks_string

  shellb_bookmark_list_long bookmarks_string _shellb_foo_bookmarks "$@" || return 1
  bookmarks_string=$(echo "${bookmarks_string}" | tail -n +2)
  _shellb_core_interactive_filter "$bookmarks_string" _shellb_foo_filtered_line _shellb_foo_filtered_line_index "instructions-$prompt" "prompt-search: " "prompt confirm: " || return 1

  echo "${_shellb_foo_filtered_line}"
  echo "${_shellb_foo_filtered_line_index}"
  echo "${_shellb_foo_bookmarks[$_shellb_foo_filtered_line_index]}"
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
