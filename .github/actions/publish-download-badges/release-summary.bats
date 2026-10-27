#!/usr/bin/env bats
# Unit tests for release-summary.sh.
# Run with: bats .github/actions/publish-download-badges/release-summary.bats
#
# The suites build their summary lines through release-summary-fixtures.bash,
# so these cases also hold the fixture to the format the stages read.

# run ! and run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/release-summary.sh
source "${BATS_TEST_DIRNAME}/release-summary.sh"

# shellcheck source=SCRIPTDIR/release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

# Succeeds when the given line is a summary line, leaving its fields in
# BASH_REMATCH.
#   match_summary_line <line>
match_summary_line() {

    [[ "$1" =~ ${RELEASE_SUMMARY_LINE_REGEX} ]]
}

@test "names the fields in line order" {

    [ "${RELEASE_SUMMARY_FIELDS[*]}" = "release published locale downloads" ]
}

@test "matches a fixture line, capturing each field" {

    match_summary_line "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"

    [ "${BASH_REMATCH[1]}" = "1.2.3" ]
    [ "${BASH_REMATCH[2]}" = "2026-09-01T00:00:00Z" ]
    [ "${BASH_REMATCH[3]}" = "en" ]
    [ "${BASH_REMATCH[4]}" = "40" ]
}

@test "matches a line with an empty locale" {

    match_summary_line "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 40)"

    [ "${BASH_REMATCH[3]}" = "" ]
    [ "${BASH_REMATCH[4]}" = "40" ]
}

@test "rejects a line missing a field" {

    run ! match_summary_line "$(printf '1.2.3\t2026-09-01T00:00:00Z\t40')"
}

@test "rejects a line with a field too many" {

    run ! match_summary_line "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)$(printf '\textra')"
}

@test "rejects a count that is not an integer" {

    run ! match_summary_line "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 4x)"
}

@test "read_release_summary reads each line's fields in line order" {

    read_release_summary <<< "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z zh-hans 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"

    [ "${RELEASE_SUMMARY_TAGS[*]}" = "1.2.4 1.2.3" ]
    [ "${RELEASE_SUMMARY_PUBLISHED_TIMES[*]}" = "2026-09-10T00:00:00Z 2026-09-01T00:00:00Z" ]
    [ "${RELEASE_SUMMARY_LOCALES[*]}" = "zh-hans en" ]
    [ "${RELEASE_SUMMARY_COUNTS[*]}" = "3 40" ]
}

@test "read_release_summary reads an empty locale as no locale" {

    read_release_summary <<< "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 40)"

    [ "${#RELEASE_SUMMARY_LOCALES[@]}" -eq 1 ]
    [ "${RELEASE_SUMMARY_LOCALES[0]}" = "" ]
}

@test "read_release_summary reads a count with a leading zero as decimal" {

    read_release_summary <<< "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 010)"

    [ "${RELEASE_SUMMARY_COUNTS[0]}" = "10" ]
}

@test "read_release_summary reads a last line that has no newline" {

    # Not a here-string: it always ends in a newline.
    read_release_summary < <(printf '1.2.4\t2026-09-10T00:00:00Z\ten\t3\n1.2.3\t2026-09-01T00:00:00Z\ten\t40')

    [ "${RELEASE_SUMMARY_COUNTS[*]}" = "3 40" ]
}

@test "read_release_summary fails on empty stdin" {

    # Not a here-string: it always carries a newline, which reads as one blank
    # line rather than as no input.
    run --separate-stderr read_release_summary < /dev/null

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"no release summary on stdin"* ]]
}

@test "read_release_summary fails on a blank line" {

    run --separate-stderr read_release_summary <<< "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)

$(build_summary_line 0.1.0 2026-01-01T00:00:00Z en 1)"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"'' is not a release summary line"* ]]
}

@test "read_release_summary fails on a line missing a field" {

    # A line without its locale.
    run --separate-stderr read_release_summary <<< "$(printf '1.2.3\t2026-09-01T00:00:00Z\t40')"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"is not a release summary line"* ]]
}

@test "read_release_summary fails on a count that is not an integer" {

    run --separate-stderr read_release_summary <<< "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 4x)"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"is not a release summary line"* ]]
}
