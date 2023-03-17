#!/usr/bin/bash

shopt -s expand_aliases

source /mnt/work/extensions/shellb/shellb.sh

file_1="111.shellbcmd"
file_2="222.shellbcmd"
file_3="333.shellbcmd"
cmd_1="echo foo"
cmd_2="echo bar"
cmd_3="echo baz"

array_files_and_commands=(
  "${file_1} | ${cmd_1}"
  "${file_2} | ${cmd_2}"
  "${file_3} | ${cmd_3}"
)

text_files_and_commands=\
"${array_files_and_commands[0]}
${array_files_and_commands[1]}
${array_files_and_commands[2]}"

array_files=(
  "${file_1}"
  "${file_2}"
  "${file_3}"
)

text_files=\
"${array_files[0]}
${array_files[1]}
${array_files[2]}"

text_proto="shellb://"

text_files_in_proto=\
"${text_proto}${array_files[0]}
${text_proto}${array_files[1]}
${text_proto}${array_files[2]}"

function fail() {
  _shellb_print_err "test failed: ${1} / ${2}"
}

function test__shellb_core_filter_row() {
  _shellb_print_nfo "${FUNCNAME[0]}"
  # test usage
  [ "$(echo "${text_files_and_commands}" | _shellb_core_filter_row 1)" == "${array_files_and_commands[0]}" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  [ "$(echo "${text_files_and_commands}" | _shellb_core_filter_row 2)" == "${array_files_and_commands[1]}" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  [ "$(echo "${text_files_and_commands}" | _shellb_core_filter_row 3)" == "${array_files_and_commands[2]}" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  # bad row should fail
  echo "${text_files_and_commands}" | _shellb_core_filter_row 4 && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_filter_row

function test__shellb_core_filter_column() {
  _shellb_print_nfo "${FUNCNAME[0]}"
  # test usage
  [ "$(echo "${file_1} | ${cmd_1}" | _shellb_core_filter_column 1)" == "${file_1}" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  [ "$(echo "${file_1} | ${cmd_1}" | _shellb_core_filter_column 2)" == "${cmd_1}" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  # bad column should fail
  echo "${file_1} | ${cmd_1}" | _shellb_core_filter_column 3 && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_filter_column

function test__shellb_core_filter_add_prefix() {
  _shellb_print_nfo "${FUNCNAME[0]}"
  # test usage; single line
  [ "$(echo "${file_1}" | _shellb_core_filter_add_prefix "${text_proto}")" == "${text_proto}${file_1}" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  # test usage; multiple lines
  [ "$(echo "${text_files}" | _shellb_core_filter_add_prefix "${text_proto}")" == "${text_files_in_proto}" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  # empty input should fail
  echo "" | _shellb_core_filter_add_prefix "${text_proto}" && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_filter_add_prefix

function test__shellb_core_is_path_below() {
  _shellb_print_nfo "${FUNCNAME[0]}"

  # if we're below, we should return 0
  _shellb_core_is_path_below "/tmp/foo"  "/tmp"  || fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/foo/" "/tmp"  || fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/foo"  "/tmp/" || fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/foo/" "/tmp"  || fail "${FUNCNAME[0]}" "${LINENO}"

  # if we're equal, we should fail
  _shellb_core_is_path_below "/tmp"  "/tmp"  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/" "/tmp"  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp"  "/tmp/" && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/" "/tmp/" && fail "${FUNCNAME[0]}" "${LINENO}"

  # if we're above, we should fail
  _shellb_core_is_path_below "/tmp"  "/tmp/foo"  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/" "/tmp/foo"  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp"  "/tmp/foo/" && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/" "/tmp/foo/" && fail "${FUNCNAME[0]}" "${LINENO}"

  # if we're equal because of .. on domain, we should fail
  _shellb_core_is_path_below "/tmp"  "/tmp/foo/.."  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/" "/tmp/foo/.."  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp"  "/tmp/foo/../" && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/" "/tmp/foo/../" && fail "${FUNCNAME[0]}" "${LINENO}"

  # if we're equal because of .. on path, we should fail
  _shellb_core_is_path_below "/tmp/foo/.."  "/tmp"  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/foo/../" "/tmp"  && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/foo/.."  "/tmp/" && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp/foo/../" "/tmp/" && fail "${FUNCNAME[0]}" "${LINENO}"

  # empty path or domain should fail
  _shellb_core_is_path_below "" "/tmp" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "/tmp" "" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"
  _shellb_core_is_path_below "" "" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_is_path_below

function test__shellb_core_is_path_below_and_owned() {
  _shellb_print_nfo "${FUNCNAME[0]}"

  # if we're below domain, we should work
  _shellb_core_is_path_below_and_owned "${_SHELLB_DB_COMMANDS}/foo" "${_SHELLB_DB_COMMANDS}" || fail "${FUNCNAME[0]}" "${LINENO}"

  # if we're equal to domain we should fail
  _shellb_core_is_path_below_and_owned "${_SHELLB_DB_COMMANDS}" "${_SHELLB_DB_COMMANDS}" && fail "${FUNCNAME[0]}" "${LINENO}"

  # we should fail if the domain is outside of shellb, even if path is below domain
  _shellb_core_is_path_below_and_owned "/tmp/foo" "/tmp" && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_is_path_below_and_owned

function test__shellb_core_calc_domain_from_user() {
  _shellb_print_nfo "${FUNCNAME[0]}"

  # test if paths are properly concatenated
  [ "$(_shellb_core_calc_domain_from_user "/foo"  "${_SHELLB_DB_COMMANDS}")"  == "${_SHELLB_DB_COMMANDS}/foo" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  [ "$(_shellb_core_calc_domain_from_user "/foo/" "${_SHELLB_DB_COMMANDS}")"  == "${_SHELLB_DB_COMMANDS}/foo" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  [ "$(_shellb_core_calc_domain_from_user "/foo"  "${_SHELLB_DB_COMMANDS}/")" == "${_SHELLB_DB_COMMANDS}/foo" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  [ "$(_shellb_core_calc_domain_from_user "/foo/" "${_SHELLB_DB_COMMANDS}/")" == "${_SHELLB_DB_COMMANDS}/foo" ] || fail "${FUNCNAME[0]}" "${LINENO}"
  [ "$(_shellb_core_calc_domain_from_user "/" "${_SHELLB_DB_COMMANDS}/")" == "${_SHELLB_DB_COMMANDS}/" ] || fail "${FUNCNAME[0]}" "${LINENO}"

  [ "$(_shellb_core_calc_domain_from_user "." "${_SHELLB_DB_COMMANDS}")" == "${_SHELLB_DB_COMMANDS}$(realpath -mq ".")" ] || fail "${FUNCNAME[0]}" "${LINENO}"

  # non-shellb domain should be rejected
  [ "$(_shellb_core_calc_domain_from_user "/foo" "/" 2>/dev/null)" == "/foo" ] && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_calc_domain_from_user

function test__shellb_core_file_get_domain_from_user() {
  _shellb_print_nfo "${FUNCNAME[0]}"

  # should fail when shellb resource is not present
  _shellb_core_file_get_domain_from_user "/foo" "${_SHELLB_DB_COMMANDS}" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"

  # should succeed when shellb resource is present
  touch "${_SHELLB_DB_COMMANDS}/foo"
  [ "$(_shellb_core_file_get_domain_from_user "/foo" "${_SHELLB_DB_COMMANDS}")" == "${_SHELLB_DB_COMMANDS}/foo" ] || fail "${FUNCNAME[0]}" "${LINENO}"

  # should fail again, when shellb resource is removed
  rm "${_SHELLB_DB_COMMANDS}/foo"
  _shellb_core_file_get_domain_from_user "/foo" "${_SHELLB_DB_COMMANDS}" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"

  # should fail when non-shellb domain is given
  _shellb_core_file_get_domain_from_user "/foo" "/" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_file_get_domain_from_user

function test__shellb_core_calc_domainrel_from_abs() {
  _shellb_print_nfo "${FUNCNAME[0]}"
  # test if absolute shellb-resource path is properly translated to shellb-proto path
  [ "$(_shellb_core_calc_domainrel_from_abs "${_SHELLB_DB_COMMANDS}/foo" "${_SHELLB_DB_COMMANDS}")" == "${_SHELLB_CFG_PROTO}foo" ] || fail "${FUNCNAME[0]}" "${LINENO}"

  # should fail when non-shellb domain is given
  _shellb_core_calc_domainrel_from_abs "/usr/foo" "/usr" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"
  # should fail when path is not below domain
  _shellb_core_calc_domainrel_from_abs "${_SHELLB_DB_COMMANDS}" "${_SHELLB_DB_COMMANDS}/foo" 2>/dev/null && fail "${FUNCNAME[0]}" "${LINENO}"
}
test__shellb_core_calc_domainrel_from_abs


demo_multiple_arrays() {
  local foo
  foo=$1
  echo "${foo}"

  [[ "$(declare -p "$2" 2>/dev/null)" =~ "declare -a" && "$(declare -p "$3" 2>/dev/null)" =~ "declare -a" ]] || { echo "Error: the 2nd and/or 3rd arguments are not arrays"; return 1; }
  local -n _array_one=$2
  local -n _array_two=$3

  printf '1: %q\n' "${_array_one[@]}"
  printf '2: %q\n' "${_array_two[@]}"

  _array_one[1]="new value"
}


function testit() {
  local _array_one=( "one argument" "another argument" )
  local _array_two=( "array two part one" "array two part two" )

  demo_multiple_arrays bar _array_one _array_two
  demo_multiple_arrays baz _array_one _array_two
}

testit

#demo_multiple_arrays bar "bax" array_two
#
#somefiles=( )
#somecommands=( )
#
#shellb_command_list .
#declare -p somefiles
#declare -p somecommands
#
#shellb_command_list . somefiles
#declare -p somefiles
#declare -p somecommands
#
#shellb_command_list . somefiles somecommands
#declare -p somefiles

#declare -p somecommands