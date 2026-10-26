#!/usr/bin/env bats
# Unit tests for write-log-notice.sh.
# Run with: bats .github/lib/log-records/writers/write-log-notice.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-notice.sh
source "${BATS_TEST_DIRNAME}/write-log-notice.sh"

@test "writes a notice record, its pairs in order, to stderr alone" {

    run --separate-stderr write_log_notice "" "example-stage: published " id "badges"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\tnotice\t\texample-stage: published \tid\tbadges')" ]
}
