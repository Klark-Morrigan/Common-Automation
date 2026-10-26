#!/usr/bin/env bats
# Unit tests for write-log-error.sh.
# Run with: bats .github/lib/log-records/writers/write-log-error.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-error.sh
source "${BATS_TEST_DIRNAME}/write-log-error.sh"

@test "writes an error record, its pairs in order, to stderr alone" {

    run --separate-stderr write_log_error "" "example-stage: could not read " id "KMU"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\terror\t\texample-stage: could not read \tid\tKMU')" ]
}
