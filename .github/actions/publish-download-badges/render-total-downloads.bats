#!/usr/bin/env bats
# Unit tests for render-total-downloads.sh.
# Run with: bats .github/actions/publish-download-badges/render-total-downloads.bats
#
# The summary arrives on stdin as summarise-release-downloads.sh prints it.
# badge-endpoint.sh and jq run for real, so each case asserts the file shields
# would fetch.

# shellcheck source=./release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

SCRIPT="${BATS_TEST_DIRNAME}/render-total-downloads.sh"

setup() {

    command -v jq > /dev/null 2>&1 || skip "jq not available in this environment"

    OUTPUT_DIR="${BATS_TEST_TMPDIR}/badges"
    mkdir -p "${OUTPUT_DIR}"

    ENDPOINT_FILE="${OUTPUT_DIR}/downloads.json"
}

# Runs the renderer with the given summary on stdin.
render() {

    local summary="$1"

    shift

    run "${SCRIPT}" "$@" <<< "${summary}"
}

# Builds the endpoint JSON expected for the given label and message.
build_expected_endpoint() {

    printf '{"schemaVersion":1,"label":"%s","message":"%s","color":"brightgreen","cacheSeconds":3600}' "$1" "$2"
}

@test "sums every release's count" {

    render "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 40)
$(build_summary_line 0.1.0 2026-01-01T00:00:00Z 1)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 44)" ]
}

@test "writes a single release's count" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 40)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 40)" ]
}

@test "writes the total as a plain integer, never abbreviated" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 5678)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 5678)" ]
}

@test "writes a zero total for releases nobody has downloaded yet" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 0)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 0)" ]
}

@test "reads a count with a leading zero as decimal" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 010)" tool "${OUTPUT_DIR}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 10)" ]
}

@test "fails and writes nothing on empty stdin" {

    # Not through render: a here-string always carries a newline, which reads
    # as one blank line rather than as no input.
    run "${SCRIPT}" tool "${OUTPUT_DIR}" < /dev/null

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no release summary on stdin"* ]]
    [ ! -e "${ENDPOINT_FILE}" ]
}

@test "fails and writes nothing when a count is not an integer" {

    # The bad line comes last, so a figure summed line by line and written
    # early would already be on disk.
    render "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 4x)" tool "${OUTPUT_DIR}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"is not a release summary line"* ]]
    [ ! -e "${ENDPOINT_FILE}" ]
}

@test "fails and writes nothing on a line missing a field" {

    render "$(printf '1.2.3\t40')" tool "${OUTPUT_DIR}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"is not a release summary line"* ]]
    [ ! -e "${ENDPOINT_FILE}" ]
}

@test "fails and writes nothing on a blank line" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 40)

$(build_summary_line 0.1.0 2026-01-01T00:00:00Z 1)" tool "${OUTPUT_DIR}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"is not a release summary line"* ]]
    [ ! -e "${ENDPOINT_FILE}" ]
}

@test "counts a last line that has no newline" {

    # Not through render: a here-string always ends in a newline.
    run "${SCRIPT}" tool "${OUTPUT_DIR}" < <(printf '1.2.4\t2026-09-10T00:00:00Z\t3\n1.2.3\t2026-09-01T00:00:00Z\t40')

    [ "${status}" -eq 0 ]
    [ "$(cat "${ENDPOINT_FILE}")" = "$(build_expected_endpoint tool 43)" ]
}

@test "fails when the output directory does not exist" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 40)" tool "${BATS_TEST_TMPDIR}/missing"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"output directory '${BATS_TEST_TMPDIR}/missing' does not exist"* ]]
}

@test "requires the label" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 40)" "" "${OUTPUT_DIR}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"label required"* ]]
}

@test "requires the output directory" {

    render "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 40)" tool

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"output directory required"* ]]
}
