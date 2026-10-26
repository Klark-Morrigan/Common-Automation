#!/usr/bin/env bats
# Unit tests for present-log-records.sh.
# Run with: bats .github/lib/log-records/presenters/present-log-records.bats
#
# The error and notice printers are stubs that name the line they were
# handed, so a case sees which printer each record reached. Messages and
# tables go through the real printers, whose suites cover their shaping; these
# cases cover the routing between them.

# shellcheck source=SCRIPTDIR/present-log-records.sh
source "${BATS_TEST_DIRNAME}/present-log-records.sh"

# shellcheck source=SCRIPTDIR/../writers/write-log-records.sh
source "${BATS_TEST_DIRNAME}/../writers/write-log-records.sh"

setup() {

    unset NO_COLOR FORCE_COLOR

    held_table_lines=()
    records_file="${BATS_TEST_TMPDIR}/records"
}

print_stub_error() {

    printf 'error printer: %s\n' "$1"
}

print_stub_notice() {

    printf 'notice printer: %s\n' "$1"
}

# Runs the loop over the records file, with the stub printers.
#   present_records
present_records() {

    run present_log_records print_stub_error print_stub_notice < "${records_file}"
}

@test "prints a message record as its values" {

    write_log_message "" "Read " id "KMU" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Read KMU" ]
}

@test "hands an error record to the error printer and a notice record to the notice printer" {

    {
        write_log_error "" "failed."
        write_log_notice "" "published."

    } 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "error printer: $(printf '#log\terror\t\tfailed.')
notice printer: $(printf '#log\tnotice\t\tpublished.')" ]
}

@test "passes a line that is not a record through unchanged" {

    printf 'retry: attempt 1 of 3 failed\n' > "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "retry: attempt 1 of 3 failed" ]
}

@test "passes a record of an unknown kind through unchanged" {

    printf '#log\tbogus\tid\tKMU\n' > "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf '#log\tbogus\tid\tKMU')" ]
}

@test "passes a row with no table open through unchanged" {

    write_log_row id "KMU.zip" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf '#log\trow\tid\tKMU.zip')" ]
}

@test "prints a table left open when input ends" {

    {
        write_log_table "Asset"
        write_log_row id "KMU.zip"

    } 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Asset
KMU.zip" ]
}

@test "prints the open table when the next one opens" {

    {
        write_log_table "Asset"
        write_log_row id "KMU.zip"
        write_log_table "Release"
        write_log_row "" "0.2.0"
        write_log_table_end

    } 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Asset
KMU.zip
Release
0.2.0" ]
}

@test "prints a line arriving while a table is held ahead of the table" {

    {
        write_log_table "Asset"
        write_log_row id "KMU.zip"
        printf 'retry: attempt 1 of 3 failed\n' >&2
        write_log_error "" "failed."
        write_log_table_end

    } 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "retry: attempt 1 of 3 failed
error printer: $(printf '#log\terror\t\tfailed.')
Asset
KMU.zip" ]
}

@test "keeps a last line that has no newline" {

    printf 'first\nlast' > "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "first
last" ]
}
