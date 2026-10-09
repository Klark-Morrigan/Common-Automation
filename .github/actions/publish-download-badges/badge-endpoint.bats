#!/usr/bin/env bats
# Unit tests for badge-endpoint.sh.
# Run with: bats .github/actions/publish-download-badges/badge-endpoint.bats
#
# jq runs for real, since the JSON it builds is what is under test.

# run ! arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=../../lib/test-helpers/crlf-jq.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/crlf-jq.bash"
# shellcheck source=./badge-endpoint.sh
source "${BATS_TEST_DIRNAME}/badge-endpoint.sh"

setup() {

    command -v jq > /dev/null 2>&1 || skip "jq not available in this environment"

    ENDPOINT_FILE="${BATS_TEST_TMPDIR}/endpoint.json"
}

@test "writes the figure in shields' endpoint schema" {

    write_badge_endpoint "${ENDPOINT_FILE}" "tool" "1234"

    [ "$(cat "${ENDPOINT_FILE}")" = \
        '{"schemaVersion":1,"label":"tool","message":"1234","color":"brightgreen","cacheSeconds":3600}' ]
}

@test "escapes a label holding JSON metacharacters" {

    write_badge_endpoint "${ENDPOINT_FILE}" 'to"ol\x' "1"

    [ "$(cat "${ENDPOINT_FILE}")" = \
        '{"schemaVersion":1,"label":"to\"ol\\x","message":"1","color":"brightgreen","cacheSeconds":3600}' ]
}

@test "replaces an earlier file" {

    write_badge_endpoint "${ENDPOINT_FILE}" "tool" "1"
    write_badge_endpoint "${ENDPOINT_FILE}" "tool" "2"

    [ "$(cat "${ENDPOINT_FILE}")" = \
        '{"schemaVersion":1,"label":"tool","message":"2","color":"brightgreen","cacheSeconds":3600}' ]
}

@test "strips the carriage return a native Windows jq writes" {

    install_crlf_jq

    write_badge_endpoint "${ENDPOINT_FILE}" "tool" "1"

    run ! grep -q $'\r' "${ENDPOINT_FILE}"
}

@test "requires the file" {

    run write_badge_endpoint "" "tool" "1"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"file required"* ]]
}

@test "requires the label" {

    run write_badge_endpoint "${ENDPOINT_FILE}" "" "1"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"label required"* ]]
    [ ! -e "${ENDPOINT_FILE}" ]
}

@test "requires the message" {

    run write_badge_endpoint "${ENDPOINT_FILE}" "tool" ""

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"message required"* ]]
    [ ! -e "${ENDPOINT_FILE}" ]
}
