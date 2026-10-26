#!/usr/bin/env bats
# Unit tests for present-log-for-github-actions.sh.
# Run with: bats .github/lib/log-records/presenters/present-log-for-github-actions.bats
#
# The records come from the log-records writers, so each case reads what a
# stage would write. present-log-records.bats covers the routing every
# presenter shares, and present-log-for-terminal.bats the shaping; these cases
# cover what this presenter does differently.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/present-log-for-github-actions.sh"

# shellcheck source=SCRIPTDIR/../../test-helpers/color-escapes.bash
source "${BATS_TEST_DIRNAME}/../../test-helpers/color-escapes.bash"

# shellcheck source=SCRIPTDIR/../writers/write-log-records.sh
source "${BATS_TEST_DIRNAME}/../writers/write-log-records.sh"

setup() {

    # A tester's own colour settings must not reach the assertions.
    unset NO_COLOR FORCE_COLOR

    records_file="${BATS_TEST_TMPDIR}/records"
}

# Runs the presenter over the records file. Its stdout is captured, so it is
# never a terminal here, as in the GitHub Actions log it shapes.
#   present_records
present_records() {

    run --separate-stderr "${SCRIPT}" < "${records_file}"
}

@test "colours a message by its role with no terminal" {

    write_log_message "" "Read " id "KMU" "" " with " count "3" "" " assets." 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Read ${YELLOW}KMU${RESET} with ${GREEN}3${RESET} assets." ]
}

@test "colours a table's cells with no terminal" {

    {
        write_log_table "Asset" "Downloads"
        write_log_row id "KMU.zip" count "120"
        write_log_table_end

    } 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Asset    Downloads
${YELLOW}KMU.zip${RESET}        ${GREEN}120${RESET}" ]
}

@test "prints plain under NO_COLOR" {

    write_log_message id "KMU" 2> "${records_file}"

    NO_COLOR=1 present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "KMU" ]
}

@test "writes an error record as a plain error annotation naming the script" {

    write_log_error "" "example-stage: could not read " id "KMU" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "::error::example-stage: could not read KMU" ]
}

@test "writes a notice record as a plain notice annotation naming the script" {

    write_log_notice "" "example-stage: published " id "badges" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "::notice::example-stage: published badges" ]
}

@test "guards a message value that would start a workflow command" {

    write_log_message "" "::stop-commands::token" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = ":${RESET}:stop-commands::token" ]
}

@test "guards a table cell that would start a workflow command, its column still aligned" {

    {
        write_log_table "Release" "Downloads"
        write_log_row "" "::error::x" count "120"
        write_log_table_end

    } 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Release     Downloads
:${RESET}:error::x        ${GREEN}120${RESET}" ]
}

@test "guards a legacy workflow command anywhere in a value" {

    write_log_message "" "Read " "" "a ##[error]b" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Read a #${RESET}#[error]b" ]
}

@test "passes a workflow command a tool wrote itself through unchanged" {

    printf '::warning::retry: attempt 1 of 3 failed\n' > "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "::warning::retry: attempt 1 of 3 failed" ]
}
