#!/usr/bin/env bats
# Unit tests for split-fields.sh.
# Run with: bats .github/lib/split-fields.bats

# shellcheck source=SCRIPTDIR/split-fields.sh
source "${BATS_TEST_DIRNAME}/split-fields.sh"

readonly TAB=$'\t'

@test "splits a line at each separator" {

    split_line_fields "${TAB}" "$(printf 'a\tb c\td')"

    [ "${#split_fields[@]}" -eq 3 ]
    [ "${split_fields[0]}" = "a" ]
    [ "${split_fields[1]}" = "b c" ]
    [ "${split_fields[2]}" = "d" ]
}

@test "splits at the separator it is given, not at a tab" {

    split_line_fields "|" "$(printf 'a\tb|c')"

    [ "${#split_fields[@]}" -eq 2 ]
    [ "${split_fields[0]}" = "$(printf 'a\tb')" ]
    [ "${split_fields[1]}" = "c" ]
}

@test "keeps empty fields in their places" {

    split_line_fields "${TAB}" "$(printf 'a\t\t\td')"

    [ "${#split_fields[@]}" -eq 4 ]
    [ "${split_fields[0]}" = "a" ]
    [ -z "${split_fields[1]}" ]
    [ -z "${split_fields[2]}" ]
    [ "${split_fields[3]}" = "d" ]
}

@test "keeps a trailing empty field" {

    split_line_fields "${TAB}" "$(printf 'a\t')"

    [ "${#split_fields[@]}" -eq 2 ]
    [ "${split_fields[0]}" = "a" ]
    [ -z "${split_fields[1]}" ]
}

@test "leaves one empty field for an empty line" {

    split_line_fields "${TAB}" ""

    [ "${#split_fields[@]}" -eq 1 ]
    [ -z "${split_fields[0]}" ]
}

@test "replaces the fields of the previous line" {

    split_line_fields "${TAB}" "$(printf 'a\tb\tc')"
    split_line_fields "${TAB}" "d"

    [ "${#split_fields[@]}" -eq 1 ]
    [ "${split_fields[0]}" = "d" ]
}
