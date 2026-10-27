#!/usr/bin/env bats
# Unit tests for build-log-record.jq.
# Run with: bats .github/lib/log-records/writers/build-log-record.bats
#
# Each case is held to the record write_log_record writes for the same values,
# since a presenter must not tell the two writers apart.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../../test-helpers/require-command.bash
source "${BATS_TEST_DIRNAME}/../../test-helpers/require-command.bash"

# shellcheck source=SCRIPTDIR/jq-log-record-args.sh
source "${BATS_TEST_DIRNAME}/jq-log-record-args.sh"

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BATS_TEST_DIRNAME}/write-log-record.sh"

# shellcheck source=SCRIPTDIR/write-log-table.sh
source "${BATS_TEST_DIRNAME}/write-log-table.sh"

setup() {

    # Without jq there is no module to run.
    require_command jq
}

# Runs build_log_record over the given kind and a JSON array of values.
#   run_build_log_record <kind> <values as a JSON array>
run_build_log_record() {

    run --separate-stderr jq -nr -L "${BATS_TEST_DIRNAME}" "${JQ_LOG_RECORD_ARGS[@]}" \
        --arg kind "$1" --argjson values "$2" \
        'include "build-log-record"; build_log_record($ARGS.named; $kind; $values)'
}

@test "builds the record write_log_record writes" {

    run_build_log_record row '["id", "KMU.zip", "", "", "count", "12"]'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(write_log_record row id "KMU.zip" "" "" count 12 2>&1)" ]
}

@test "builds the marker and the kind alone for a record with no values" {

    run_build_log_record end '[]'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(write_log_record end 2>&1)" ]
}

@test "writes a number as its digits" {

    run_build_log_record row '["count", 12]'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(write_log_record row count 12 2>&1)" ]
}

@test "flattens a tab, a newline and a carriage return inside a text to spaces" {

    run_build_log_record message '["", "a\tb\nc\rd"]'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(write_log_record message "" "$(printf 'a\tb\nc\rd')" 2>&1)" ]
}

@test "builds the table record write_log_table writes, each column plain" {

    run --separate-stderr jq -nr -L "${BATS_TEST_DIRNAME}" "${JQ_LOG_RECORD_ARGS[@]}" \
        'include "build-log-record"; build_log_table($ARGS.named; ["Asset", "Locale origin"])'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(write_log_table "Asset" "Locale origin" 2>&1)" ]
}

@test "fails, building no record, when the values do not pair up" {

    run_build_log_record row '["id", "KMU.zip", "count"]'

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"build_log_record: a row record takes role and text pairs; got 3 values."* ]]
}
