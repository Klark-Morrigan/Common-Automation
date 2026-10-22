#!/usr/bin/env bats
# Unit tests for split-tab-fields.sh.
# Run with: bats .github/lib/split-tab-fields.bats

# shellcheck source=SCRIPTDIR/split-tab-fields.sh
source "${BATS_TEST_DIRNAME}/split-tab-fields.sh"

@test "splits a line at each tab" {

    split_tab_fields "$(printf 'a\tb c\td')"

    [ "${#split_fields[@]}" -eq 3 ]
    [ "${split_fields[0]}" = "a" ]
    [ "${split_fields[1]}" = "b c" ]
    [ "${split_fields[2]}" = "d" ]
}

@test "keeps empty fields in their places" {

    split_tab_fields "$(printf 'a\t\t\td')"

    [ "${#split_fields[@]}" -eq 4 ]
    [ "${split_fields[0]}" = "a" ]
    [ -z "${split_fields[1]}" ]
    [ -z "${split_fields[2]}" ]
    [ "${split_fields[3]}" = "d" ]
}

@test "keeps a trailing empty field" {

    split_tab_fields "$(printf 'a\t')"

    [ "${#split_fields[@]}" -eq 2 ]
    [ "${split_fields[0]}" = "a" ]
    [ -z "${split_fields[1]}" ]
}

@test "leaves one empty field for an empty line" {

    split_tab_fields ""

    [ "${#split_fields[@]}" -eq 1 ]
    [ -z "${split_fields[0]}" ]
}

@test "replaces the fields of the previous line" {

    split_tab_fields "$(printf 'a\tb\tc')"
    split_tab_fields "d"

    [ "${#split_fields[@]}" -eq 1 ]
    [ "${split_fields[0]}" = "d" ]
}
