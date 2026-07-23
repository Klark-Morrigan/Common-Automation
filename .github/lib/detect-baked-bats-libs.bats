#!/usr/bin/env bats
# Unit tests for detect-baked-bats-libs.sh - the per-library decision on
# whether bats-action should install each bats helper library. A library is
# skipped (install=false) when it is already baked OR when the runner cannot
# sudo without a password (the install writes to the base dir via sudo, so it
# cannot run there at all). Each case points the script at a temp base dir it
# populates with load.bash files and forces the sudo capability via
# BATS_LIBS_CAN_SUDO, so neither the real /usr/lib nor the test host's sudo
# config is touched.
# Run with: bats lib/detect-baked-bats-libs.bats

SCRIPT="${BATS_TEST_DIRNAME}/detect-baked-bats-libs.sh"

setup() {
    BASE="$(mktemp -d)"
    # Default to "can sudo" (the GitHub-hosted case) so the baked-vs-absent
    # behaviour is what each test exercises; the no-sudo cases override it.
    export BATS_LIBS_CAN_SUDO=1
}

teardown() {
    rm -rf "${BASE}"
}

# Marks a library as installed by creating <base>/bats-<lib>/load.bash.
_bake_lib() {
    mkdir -p "${BASE}/bats-${1}"
    touch "${BASE}/bats-${1}/load.bash"
}

@test "with sudo, an empty base dir reports every library as install=true" {
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=true"* ]]
    [[ "${output}" == *"assert_install=true"* ]]
    [[ "${output}" == *"detik_install=true"* ]]
    [[ "${output}" == *"file_install=true"* ]]
}

@test "with sudo, a baked library reports install=false while the rest stay true" {
    _bake_lib support
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=false"* ]]
    [[ "${output}" == *"assert_install=true"* ]]
    [[ "${output}" == *"detik_install=true"* ]]
    [[ "${output}" == *"file_install=true"* ]]
}

@test "with sudo, all libraries baked reports install=false for every one" {
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

@test "with sudo, a bats-<lib> directory without load.bash still counts as absent" {
    # Presence is keyed on load.bash, not the directory: a half-populated
    # tree (dir created, extract failed) must reinstall, not be skipped.
    mkdir -p "${BASE}/bats-support"
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=true"* ]]
}

@test "without passwordless sudo, every absent library is skipped (install=false)" {
    # The core self-hosted fix: an install would sudo-write to the base dir
    # and fail on "a password is required", so no library is installed even
    # when absent - only baked libraries are available.
    export BATS_LIBS_CAN_SUDO=0
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=false"* ]]
    [[ "${output}" == *"assert_install=false"* ]]
    [[ "${output}" == *"detik_install=false"* ]]
    [[ "${output}" == *"file_install=false"* ]]
}

@test "without passwordless sudo, a baked library is also skipped" {
    export BATS_LIBS_CAN_SUDO=0
    _bake_lib support
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"support_install=false"* ]]
    [[ "${output}" == *"detik_install=false"* ]]
}

@test "emits exactly one line per bats-action library" {
    run "${SCRIPT}" "${BASE}"
    [ "${status}" -eq 0 ]
    [ "$(printf '%s\n' "${output}" | grep -c '_install=')" -eq 4 ]
}
