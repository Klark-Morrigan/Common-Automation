#!/usr/bin/env bats
# Unit tests for get-bats-version.sh - the single accessor for the
# bats-core version. Two branches: an override argument echoed verbatim,
# and the default path that reads BATS_VERSION from the adjacent
# versions.env.
# Run with: bats lib/get-bats-version.bats

SCRIPT="${BATS_TEST_DIRNAME}/get-bats-version.sh"
VERSIONS_ENV="${BATS_TEST_DIRNAME}/versions.env"

@test "echoes an override argument verbatim" {
    run "${SCRIPT}" "9.9.9"
    [ "${status}" -eq 0 ]
    [ "${output}" = "9.9.9" ]
}

@test "override wins without reading versions.env" {
    # An arbitrary override that is not a real version must still pass
    # through untouched, proving the default file is not consulted.
    run "${SCRIPT}" "not-a-real-version"
    [ "${status}" -eq 0 ]
    [ "${output}" = "not-a-real-version" ]
}

@test "with no argument returns the canonical version from versions.env" {
    # Source versions.env here rather than hardcoding the number, so the
    # test asserts the accessor faithfully returns the single source of
    # truth and cannot drift when the version is bumped.
    # shellcheck source=./versions.env
    source "${VERSIONS_ENV}"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "${BATS_VERSION}" ]
}

@test "the returned default version is non-empty" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -n "${output}" ]
}
