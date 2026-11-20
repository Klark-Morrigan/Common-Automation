#!/usr/bin/env bats
#
# Tests for
# trailing-whitespace-pattern.sh,
# the one rule for trailing whitespace.
#
# Every sample states its whitespace as an escape, as in $'A line   ',
# never as literal spaces at the end of a line,
# so neither an editor nor the trim can rewrite the samples.

setup() {

    # shellcheck source=SCRIPTDIR/trailing-whitespace-pattern.sh
    source "${BATS_TEST_DIRNAME}/trailing-whitespace-pattern.sh"
}

@test "matches trailing spaces" {

    run grep -q -- "${TRAILING_WHITESPACE_PATTERN}" <<< $'A line\x20\x20\x20'

    [ "${status}" -eq 0 ]
}

@test "matches a trailing tab" {

    run grep -q -- "${TRAILING_WHITESPACE_PATTERN}" <<< $'A line\t'

    [ "${status}" -eq 0 ]
}

@test "matches trailing spaces before a carriage return" {

    run grep -q -- "${TRAILING_WHITESPACE_PATTERN}" <<< $'A line\x20\x20\r'

    [ "${status}" -eq 0 ]
}

@test "leaves a line whose only spaces are inside it alone" {

    run grep -q -- "${TRAILING_WHITESPACE_PATTERN}" <<< $'A\x20\x20line'

    [ "${status}" -eq 1 ]
}

@test "captures the carriage return, so a substitution keeps it" {

    run bash -c 'printf "A line   \r\n" | sed -b "s/$1/\\1/" | od -c | head -1 | tr -s " "' \
        _ "${TRAILING_WHITESPACE_PATTERN}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "0000000 A l i n e \r \n" ]
}
