#!/usr/bin/env bats
# Unit tests for get-tool-version.sh.
# Run with: bats .github/lib/get-tool-version.bats
#
# Each case runs a copy of the script beside a fixture versions.env in
# BATS_TEST_TMPDIR, so no case depends on the real pins.

SCRIPT="${BATS_TEST_DIRNAME}/get-tool-version.sh"

setup() {

    COPIED_SCRIPT="${BATS_TEST_TMPDIR}/get-tool-version.sh"
    cp "${SCRIPT}" "${COPIED_SCRIPT}"
}

write_versions_env() {

    printf '%s\n' "$@" > "${BATS_TEST_TMPDIR}/versions.env"
}

@test "prints the pinned version from versions.env" {

    write_versions_env 'BATS_VERSION=1.11.0' 'YAMLLINT_VERSION=1.35.1'
    run "${COPIED_SCRIPT}" YAMLLINT_VERSION

    [ "${status}" -eq 0 ]
    [ "${output}" = "1.35.1" ]
}

@test "prints an override verbatim without reading versions.env" {

    # No versions.env beside the copy: reading it would fail the run.
    run "${COPIED_SCRIPT}" YAMLLINT_VERSION "not-a-real-version"

    [ "${status}" -eq 0 ]
    [ "${output}" = "not-a-real-version" ]
}

@test "fails naming the key and the file when the pin is missing" {

    write_versions_env 'BATS_VERSION=1.11.0'
    run "${COPIED_SCRIPT}" YAMLLINT_VERSION

    [ "${status}" -eq 1 ]
    [ "${output}" = "get-tool-version: YAMLLINT_VERSION is not set in ${BATS_TEST_TMPDIR}/versions.env" ]
}

@test "fails when the pin is empty" {

    write_versions_env 'YAMLLINT_VERSION='
    run "${COPIED_SCRIPT}" YAMLLINT_VERSION

    [ "${status}" -eq 1 ]
}

@test "fails when only the environment holds the key" {

    write_versions_env 'BATS_VERSION=1.11.0'
    export YAMLLINT_VERSION="9.9.9"

    run "${COPIED_SCRIPT}" YAMLLINT_VERSION

    [ "${status}" -eq 1 ]
}

@test "rejects a key that is not a plain <NAME>_VERSION without evaluating it" {

    write_versions_env 'YAMLLINT_VERSION=1.35.1'
    marker="${BATS_TEST_TMPDIR}/evaluated"

    run "${COPIED_SCRIPT}" "YAMLLINT_VERSION[\$(touch ${marker})]"

    [ "${status}" -eq 2 ]
    [ ! -e "${marker}" ]
}

@test "rejects a missing key" {

    write_versions_env 'YAMLLINT_VERSION=1.35.1'
    run "${COPIED_SCRIPT}"

    [ "${status}" -eq 2 ]
}

@test "resolves every pin in the real versions.env" {

    # Guards the shipped file: a key left empty there fails here, not in
    # the CI run that first needs it.
    mapfile -t keys < <(grep -oE '^[A-Z][A-Z0-9_]*_VERSION' "${BATS_TEST_DIRNAME}/versions.env")

    [ "${#keys[@]}" -gt 0 ]

    for key in "${keys[@]}"; do

        run "${SCRIPT}" "${key}"

        [ "${status}" -eq 0 ]
        [ -n "${output}" ]
    done
}
