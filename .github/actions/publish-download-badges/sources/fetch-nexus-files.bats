#!/usr/bin/env bats
# Unit tests for fetch-nexus-files.sh.
# Run with: bats .github/actions/publish-download-badges/sources/fetch-nexus-files.bats
#
# The curl stub replays an answer built through nexus-files-fixtures.bash. jq
# runs for real, since the script's checks on that answer are under test.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/command-stub.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/command-stub.bash"

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/crlf-jq.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/crlf-jq.bash"

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/require-command.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/require-command.bash"

# shellcheck source=SCRIPTDIR/nexus-files-fixtures.bash
source "${BATS_TEST_DIRNAME}/nexus-files-fixtures.bash"

SCRIPT="${BATS_TEST_DIRNAME}/fetch-nexus-files.sh"
GAME_UNDER_TEST="2672"
MOD_UNDER_TEST="160"

setup() {

    # Without jq there are no checks to run, so nothing meaningful to assert.
    require_command jq

    # Built before the stub or the CRLF wrapper goes on PATH.
    TWO_FILES_ANSWER="$(build_files_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 2 other 0.4.0 ARCHIVED 7 7)")"

    install_command_stub curl

    export NEXUS_GAME_ID="${GAME_UNDER_TEST}"
    export NEXUS_MOD_ID="${MOD_UNDER_TEST}"

    # A retry would otherwise sleep for seconds between attempts.
    export RETRY_BACKOFF_INITIAL_SECONDS=0
}

# Prints the request body the last curl call sent: the argument after --data.
read_request_body() {

    grep -A 1 -x -- "--data" "${CURL_ARGS_FILE}" | tail -n 1
}

@test "prints Nexus' answer unchanged" {

    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${TWO_FILES_ANSWER}" ]
}

@test "posts the query to Nexus' GraphQL API" {

    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]

    grep -qx "https://api.nexusmods.com/v2/graphql" "${CURL_ARGS_FILE}"
    grep -qx "Content-Type: application/json" "${CURL_ARGS_FILE}"
}

@test "cuts off a stalled connection and a stalled request" {

    # curl sets no time limit of its own, so a stall would hold the job
    # until Actions cancelled it.
    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]

    grep -A 1 -x -- "--connect-timeout" "${CURL_ARGS_FILE}" | grep -qx "10"
    grep -A 1 -x -- "--max-time" "${CURL_ARGS_FILE}" | grep -qx "60"
}

@test "sends the ids as GraphQL variables, never in the query text" {

    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]

    local request_body
    request_body="$(read_request_body)"

    [ "$(jq -c '.variables' <<< "${request_body}")" = '{"modId":"160","gameId":"2672"}' ]
    [[ "$(jq -r '.query' <<< "${request_body}")" != *"160"* ]]
    [[ "$(jq -r '.query' <<< "${request_body}")" != *"2672"* ]]
}

@test "sends an id holding quotes as a variable, leaving the query intact" {

    # Spliced into the query text, the quote would end the string early.
    export NEXUS_MOD_ID='160") { x } #'
    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(jq -r '.variables.modId' <<< "$(read_request_body)")" = "${NEXUS_MOD_ID}" ]
}

@test "asks for each file's id, name, version, category and total downloads" {

    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(jq -r '.query' <<< "$(read_request_body)")" == \
        *"modFiles(modId: \$modId, gameId: \$gameId) { fileId name version category totalDownloads }"* ]]
}

@test "logs the ids it queries and how many files came back" {

    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Querying the files of Nexus mod 160 in game 2672."* ]]
    [[ "${stderr}" == *"Nexus returned 2 files for mod 160."* ]]
}

@test "strips the carriage returns a native Windows jq writes" {

    # The file count is read from jq, so a carriage return would split its
    # log line.
    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"
    install_crlf_jq

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Nexus returned 2 files for mod 160."* ]]
}

@test "fails naming the mod when the answer is not JSON" {

    # What a proxy's HTML error page looks like under a 200.
    export CURL_STUB_STDOUT="<html>Bad Gateway</html>"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"Nexus' answer for the files of mod 160 is not a JSON object."* ]]
}

@test "fails naming the mod when the answer is empty" {

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"Nexus' answer for the files of mod 160 is not a JSON object."* ]]
}

@test "fails naming the mod and the message when the answer carries GraphQL errors" {

    # GraphQL reports these under HTTP 200, so curl succeeds.
    export CURL_STUB_STDOUT='{"errors":[{"message":"Field '"'"'nope'"'"' does not exist"}],"data":null}'

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"Nexus answered the query for the files of mod 160 with errors: Field 'nope' does not exist"* ]]
}

@test "retries a server error and prints only the attempt that succeeded" {

    # The failed attempt printed a body before failing. Kept beside the
    # retry's answer, it would make the output two documents.
    export CURL_STUB_STDOUT_1='{"partial":'
    export CURL_STUB_STDERR_1="curl: (22) The requested URL returned error: 502" CURL_STUB_EXIT_1=22
    export CURL_STUB_STDOUT="${TWO_FILES_ANSWER}"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(count_command_calls curl)" -eq 2 ]
    [ "${output}" = "${TWO_FILES_ANSWER}" ]
}

@test "fails without retrying when Nexus answers with a client error" {

    # A rate limit or a bad request answers the same on an immediate retry.
    export CURL_STUB_STDERR="curl: (22) The requested URL returned error: 429" CURL_STUB_EXIT=22

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [ "$(count_command_calls curl)" -eq 1 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"could not query the files of Nexus mod 160"* ]]
    [[ "${stderr}" == *"returned error: 429"* ]]
}

@test "requires the game id" {

    unset NEXUS_GAME_ID
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"NEXUS_GAME_ID is required"* ]]

    # Cheapest checks first: an incomplete invocation costs no request.
    [ ! -f "${CURL_CALLS_FILE}" ]
}

@test "requires the mod id" {

    unset NEXUS_MOD_ID
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"NEXUS_MOD_ID is required"* ]]
    [ ! -f "${CURL_CALLS_FILE}" ]
}
