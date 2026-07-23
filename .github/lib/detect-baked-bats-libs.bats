#!/usr/bin/env bats
# Unit tests for detect-baked-bats-libs.sh - the per-library baked/absent
# probe that decides whether bats-action should install each bats helper
# library. Each case points the script at a temp base dir it populates
# with load.bash files, so the "present" branch is exercised without
# touching the real /usr/lib.
# Run with: bats lib/detect-baked-bats-libs.bats

SCRIPT="${BATS_TEST_DIRNAME}/detect-baked-bats-libs.sh"

setup() {
    BASE="$(mktemp -d)"
}

teardown() {
    rm -rf "${BASE}"
}

# Marks a library as installed by creating <base>/bats-<lib>/load.bash.
_bake_lib() {
    mkdir -p "${BASE}/bats-${1}"
    touch "${BASE}/bats-${1}/load.bash"
}

@test "an empty base dir reports every library as install=true" {
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=true"* ]]
    [[ "${output}" == *"assert_install=true"* ]]
    [[ "${output}" == *"detik_install=true"* ]]
    [[ "${output}" == *"file_install=true"* ]]
}

@test "a baked library reports install=false while the rest stay true" {
    _bake_lib support
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=false"* ]]
    [[ "${output}" == *"assert_install=true"* ]]
    [[ "${output}" == *"detik_install=true"* ]]
    [[ "${output}" == *"file_install=true"* ]]
}

@test "all libraries baked reports install=false for every one" {
    _bake_lib support
    _bake_lib assert
    _bake_lib detik
    _bake_lib file
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=false"* ]]
    [[ "${output}" == *"assert_install=false"* ]]
    [[ "${output}" == *"detik_install=false"* ]]
    [[ "${output}" == *"file_install=false"* ]]
}

@test "a bats-<lib> directory without load.bash still counts as absent" {
    # Presence is keyed on load.bash, not the directory: a half-populated
    # tree (dir created, extract failed) must reinstall, not be skipped.
    mkdir -p "${BASE}/bats-support"
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=true"* ]]
}

@test "emits exactly one line per bats-action library" {
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [ "$(printf '%s\n' "${output}" | grep -c '_install=')" -eq 4 ]
}
