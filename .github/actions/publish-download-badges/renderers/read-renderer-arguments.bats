#!/usr/bin/env bats
# Unit tests for read-renderer-arguments.sh.
# Run with: bats .github/actions/publish-download-badges/renderers/read-renderer-arguments.bats
#
# read_release_summary runs for real: its own suite covers the line format,
# and these cases read back what it left.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/read-renderer-arguments.sh
source "${BATS_TEST_DIRNAME}/read-renderer-arguments.sh"

# shellcheck source=SCRIPTDIR/../summaries/release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/../summaries/release-summary-fixtures.bash"

setup() {

    OUTPUT_DIR="${BATS_TEST_TMPDIR}/badges"
    mkdir -p "${OUTPUT_DIR}"

    SUMMARY="$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"
}

@test "leaves the label and the output directory for the renderer" {

    read_renderer_arguments tool "${OUTPUT_DIR}" <<< "${SUMMARY}"

    [ "${RENDERER_LABEL}" = "tool" ]
    [ "${RENDERER_OUTPUT_DIR}" = "${OUTPUT_DIR}" ]
}

@test "reads the summary on stdin" {

    read_renderer_arguments tool "${OUTPUT_DIR}" <<< "${SUMMARY}"

    [ "${RELEASE_SUMMARY_COUNTS[*]}" = "40" ]
}

@test "fails when the output directory does not exist" {

    run --separate-stderr read_renderer_arguments tool "${BATS_TEST_TMPDIR}/missing" <<< "${SUMMARY}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"output directory '${BATS_TEST_TMPDIR}/missing' does not exist"* ]]
}

@test "requires the label" {

    run --separate-stderr read_renderer_arguments "" "${OUTPUT_DIR}" <<< "${SUMMARY}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"label is required"* ]]
}

@test "requires the output directory" {

    run --separate-stderr read_renderer_arguments tool <<< "${SUMMARY}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"output directory is required"* ]]
}

@test "fails on a malformed summary" {

    run --separate-stderr read_renderer_arguments tool "${OUTPUT_DIR}" <<< "$(build_summary_line 1.2.3 x en 4x)"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"is not a release summary line"* ]]
}
