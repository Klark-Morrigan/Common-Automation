#!/usr/bin/env bats
# Unit tests for write-log-table-end.sh.
# Run with: bats .github/lib/log-records/writers/write-log-table-end.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-table-end.sh
source "${BATS_TEST_DIRNAME}/write-log-table-end.sh"

@test "writes an end record, to stderr alone" {

    run --separate-stderr write_log_table_end

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\tend')" ]
}
