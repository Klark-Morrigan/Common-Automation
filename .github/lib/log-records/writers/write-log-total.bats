#!/usr/bin/env bats
# Unit tests for write-log-total.sh.
# Run with: bats .github/lib/log-records/writers/write-log-total.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-total.sh
source "${BATS_TEST_DIRNAME}/write-log-total.sh"

@test "writes a total record, a pair per cell, to stderr alone" {

    run --separate-stderr write_log_total locale en count 120

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\ttotal\tlocale\ten\tcount\t120')" ]
}
