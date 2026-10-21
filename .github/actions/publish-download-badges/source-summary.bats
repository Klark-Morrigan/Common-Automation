#!/usr/bin/env bats
# Unit tests for source-summary.sh.
# Run with: bats .github/actions/publish-download-badges/source-summary.bats
#
# The suites build their source lines through source-summary-fixtures.bash,
# so these cases also hold the fixture to the format the stages read.

# run ! arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/source-summary.sh
source "${BATS_TEST_DIRNAME}/source-summary.sh"

# shellcheck source=SCRIPTDIR/source-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/source-summary-fixtures.bash"

# Succeeds when the given line is a source summary line, leaving its fields in
# BASH_REMATCH.
#   match_source_summary_line <line>
match_source_summary_line() {

    [[ "$1" =~ ${SOURCE_SUMMARY_LINE_REGEX} ]]
}

@test "names the fields in line order" {

    [ "${SOURCE_SUMMARY_FIELDS[*]}" = "version locale downloads" ]
}

@test "matches a fixture line, capturing its version, locale and count" {

    match_source_summary_line "$(build_source_summary_line 1.2.3 en 40)"

    [ "${BASH_REMATCH[1]}" = "1.2.3" ]
    [ "${BASH_REMATCH[2]}" = "en" ]
    [ "${BASH_REMATCH[3]}" = "40" ]
}

@test "matches a line with an empty locale" {

    match_source_summary_line "$(build_source_summary_line 1.2.3 "" 40)"

    [ "${BASH_REMATCH[2]}" = "" ]
    [ "${BASH_REMATCH[3]}" = "40" ]
}

@test "rejects a line missing a field" {

    run ! match_source_summary_line "$(printf '1.2.3\t40')"
}

@test "rejects a line with a field too many" {

    run ! match_source_summary_line "$(build_source_summary_line 1.2.3 en 40)$(printf '\textra')"
}

@test "rejects an empty version" {

    run ! match_source_summary_line "$(build_source_summary_line "" en 40)"
}

@test "rejects a count that is not an integer" {

    run ! match_source_summary_line "$(build_source_summary_line 1.2.3 en 4x)"
}
