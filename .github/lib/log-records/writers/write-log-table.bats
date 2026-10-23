#!/usr/bin/env bats
# Unit tests for write-log-table.sh.
# Run with: bats .github/lib/log-records/writers/write-log-table.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-table.sh
source "${BATS_TEST_DIRNAME}/write-log-table.sh"

@test "writes a table record, each column name under the plain role, to stderr alone" {

    run --separate-stderr write_log_table Asset Downloads

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\ttable\t\tAsset\t\tDownloads')" ]
}

@test "keeps a column name that holds spaces as one column" {

    run --separate-stderr write_log_table "Locale origin" Downloads

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$(printf '#log\ttable\t\tLocale origin\t\tDownloads')" ]
}
