#!/usr/bin/env bats
# Unit tests for present-log-for-terminal.sh.
# Run with: bats .github/lib/log-records/presenters/present-log-for-terminal.bats
#
# The records come from the log-records writers, so each case reads what a
# stage would write. present-log-records.bats covers the routing every
# presenter shares; these cases cover the shaped log a person sees, and what
# this presenter does with error and notice records.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/present-log-for-terminal.sh"

readonly YELLOW=$'\033[38;2;255;230;0m'
readonly GREEN=$'\033[32m'
readonly GREY=$'\033[90m'
readonly RED=$'\033[31m'
readonly RESET=$'\033[0m'

# shellcheck source=SCRIPTDIR/../writers/write-log-records.sh
source "${BATS_TEST_DIRNAME}/../writers/write-log-records.sh"

setup() {

    # A tester's own colour settings must not reach the assertions.
    unset NO_COLOR FORCE_COLOR

    records_file="${BATS_TEST_TMPDIR}/records"
}

# Runs the presenter over the records file.
#   present_records
present_records() {

    run --separate-stderr "${SCRIPT}" < "${records_file}"
}

# Writes a table of two releases' assets, with a total per locale, to the
# records file.
#   write_asset_table_records
write_asset_table_records() {

    {
        write_log_table "Asset" "Locale" "Downloads" "Note"
        write_log_row id "KMU-0.2.0-en.zip" locale "en" count "120" "" ""
        write_log_row id "KMU-0.2.0-zh-hans.zip" locale "zh-hans" count "7" "" ""
        write_log_row stale "KMU-en.version" "" "" stale "26686" invalid "its name does not match"
        write_log_total "" "" locale "en" count "120" "" ""
        write_log_total "" "" locale "zh-hans" count "7" "" ""
        write_log_table_end

    } 2> "${records_file}"
}

@test "prints a message's values in order, plain when stdout is not a terminal" {

    write_log_message "" "Read " id "KMU" "" " with " count "3" "" " assets." 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Read KMU with 3 assets." ]
}

@test "colours each message value by its role under FORCE_COLOR" {

    write_log_message id "a" count "b" current "c" stale "d" invalid "e" "" "f" unknown "g" 2> "${records_file}"

    FORCE_COLOR=1 present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "${YELLOW}a${RESET}${GREEN}b${RESET}${GREEN}c${RESET}${GREY}d${RESET}${RED}e${RESET}fg" ]
}

@test "prints plain under NO_COLOR, even when colour is forced" {

    write_log_message id "KMU" 2> "${records_file}"

    NO_COLOR=1 FORCE_COLOR=1 present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "KMU" ]
}

@test "upper-cases a locale" {

    write_log_message "" "Default locale: " locale "zh-hans" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Default locale: ZH-HANS" ]
}

@test "pads a table, right-aligns its counts and prints its totals under a rule" {

    write_asset_table_records

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Asset                  Locale   Downloads  Note
KMU-0.2.0-en.zip       EN             120
KMU-0.2.0-zh-hans.zip  ZH-HANS          7
KMU-en.version                      26686  its name does not match
------------------------------------------------------------------
                       EN             120
                       ZH-HANS          7" ]
}

@test "keeps a coloured table's columns aligned once the escapes are stripped" {

    local plain_output

    write_asset_table_records

    present_records
    plain_output="${output}"

    FORCE_COLOR=1 present_records

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${GREY}26686${RESET}  ${RED}its name does not match${RESET}"* ]]
    [ "$(sed 's/\x1b\[[0-9;]*m//g' <<< "${output}")" = "${plain_output}" ]
}

@test "left-aligns a column holding words beside its numbers" {

    {
        write_log_table "Release" "Downloads"
        write_log_row "" "0.2.0" count "120"
        write_log_row "" "10" count "7"
        write_log_table_end

    } 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "Release  Downloads
0.2.0          120
10               7" ]
}

@test "prints an error record in red, naming the script" {

    write_log_error "" "example-stage: could not read " id "KMU" 2> "${records_file}"

    FORCE_COLOR=1 present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "${RED}example-stage: could not read KMU${RESET}" ]
}

@test "prints a notice record as a plain line, naming the script" {

    write_log_notice "" "example-stage: published badges." 2> "${records_file}"

    FORCE_COLOR=1 present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "example-stage: published badges." ]
}

# No terminal reader runs workflow commands, so nothing is hidden in its text.
@test "prints a value that looks like a workflow command unguarded" {

    write_log_message "" "::error::fake" 2> "${records_file}"

    present_records

    [ "${status}" -eq 0 ]
    [ "${output}" = "::error::fake" ]
}
