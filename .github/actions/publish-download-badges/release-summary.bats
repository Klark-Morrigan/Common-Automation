#!/usr/bin/env bats
# Unit tests for release-summary.sh.
# Run with: bats .github/actions/publish-download-badges/release-summary.bats
#
# The suites build their summary lines through release-summary-fixtures.bash,
# so these cases also hold the fixture to the format the stages read.

# run ! arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=./release-summary.sh
source "${BATS_TEST_DIRNAME}/release-summary.sh"

# shellcheck source=./release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

# Succeeds when the given line is a summary line, leaving its count in
# BASH_REMATCH[1].
#   match_summary_line <line>
match_summary_line() {

    [[ "$1" =~ ${RELEASE_SUMMARY_LINE_REGEX} ]]
}

@test "names the fields in line order" {

    [ "${RELEASE_SUMMARY_FIELDS[*]}" = "release published locale downloads" ]
}

@test "matches a fixture line, capturing its count" {

    match_summary_line "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"

    [ "${BASH_REMATCH[1]}" = "40" ]
}

@test "matches a line with an empty locale" {

    match_summary_line "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 40)"

    [ "${BASH_REMATCH[1]}" = "40" ]
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
