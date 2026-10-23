#!/usr/bin/env bats
# Unit tests for write-log-row.sh.
# Run with: bats .github/lib/log-records/writers/write-log-row.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-row.sh
source "${BATS_TEST_DIRNAME}/write-log-row.sh"

@test "writes a row record, a pair per cell, to stderr alone" {

    run --separate-stderr write_log_row id "KMU-0.2.0-en.zip" count 120

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\trow\tid\tKMU-0.2.0-en.zip\tcount\t120')" ]
}
