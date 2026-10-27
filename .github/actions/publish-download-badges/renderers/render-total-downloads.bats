#!/usr/bin/env bats
# Unit tests for render-total-downloads.sh.
# Run with: bats .github/actions/publish-download-badges/renderers/render-total-downloads.bats
#
# The summary arrives on stdin as summarise-release-downloads.sh prints it.
# badge-endpoint.sh and jq run for real, so each case asserts the file shields
# would fetch.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/../release-summary-fixtures.bash"

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/require-command.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/require-command.bash"

# The expected log records come from the writers the renderer calls.
# shellcheck source=SCRIPTDIR/../../../lib/log-records/writers/write-log-records.sh
source "${BATS_TEST_DIRNAME}/../../../lib/log-records/writers/write-log-records.sh"

SCRIPT="${BATS_TEST_DIRNAME}/render-total-downloads.sh"

setup() {

    require_command jq

    OUTPUT_DIR="${BATS_TEST_TMPDIR}/badges"
    mkdir -p "${OUTPUT_DIR}"

    ENDPOINT_FILE="${OUTPUT_DIR}/downloads.json"
}

# Runs the renderer with the given summary on stdin.
render() {

    local summary="$1"

    shift

    run --separate-stderr "${SCRIPT}" "$@" <<< "${summary}"
}

# Builds the endpoint JSON expected for the given label and message.
build_expected_endpoint() {

    printf '{"schemaVersion":1,"label":"%s","message":"%s","color":"brightgreen","cacheSeconds":300}' "$1" "$2"
}

@test "sums every release's count" {

    render "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 0.1.0 2026-01-01T00:00:00Z en 1)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 44)" ]
}

@test "sums every locale of a release into the total" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 55)" ]
}

@test "sums a line with an empty locale into the total" {

    # A project keeping no locales prints its counts under none.
    render "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z "" 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 40)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 43)" ]
}

@test "writes a single release's count" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 40)" ]
}

@test "writes the total as a plain integer, never abbreviated" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 5678)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 5678)" ]
}

@test "writes a zero total for releases nobody has downloaded yet" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 0)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 0)" ]
}

@test "logs the lines it summed, the total and the file, to stderr alone" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$({
        write_log_message \
            "" "Summed " count "2" "" " lines, one per release and locale: " count "55" "" " downloads."
        write_log_message \
            "" "Wrote " id "downloads.json" "" ": label '" id "tool" "" "', message '55'."

    } 2>&1)" ]
}

@test "fails and writes nothing on a malformed summary line" {

    # The line format is read_release_summary's to check; this case holds the
    # renderer to failing through it. The bad line comes last, so a figure
    # summed line by line and written early would already be on disk.
    render "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 4x)" tool "${OUTPUT_DIR}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"render-total-downloads: '1.2.3"*"' is not a release summary line"* ]]
    [ ! -e "${ENDPOINT_FILE}" ]
}

@test "fails when the output directory does not exist" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" tool "${BATS_TEST_TMPDIR}/missing"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"output directory '${BATS_TEST_TMPDIR}/missing' does not exist"* ]]
}

@test "requires the label" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" "" "${OUTPUT_DIR}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"label is required"* ]]
}

@test "requires the output directory" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" tool

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"output directory is required"* ]]
}
