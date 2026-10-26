#!/usr/bin/env bats
# Unit tests for write-log-records.sh.
# Run with: bats .github/lib/log-records/writers/write-log-records.bats

# shellcheck source=SCRIPTDIR/write-log-records.sh
source "${BATS_TEST_DIRNAME}/write-log-records.sh"

@test "defines every writer" {

    local writer_name

    for writer_name in write_log_error write_log_message write_log_notice write_log_row write_log_table \
        write_log_table_end write_log_total; do

        [ "$(type -t "${writer_name}")" = "function" ]
    done
}

@test "defines the format the writers write" {

    [ "${LOG_RECORD_MARKER}" = "#log" ]
}
