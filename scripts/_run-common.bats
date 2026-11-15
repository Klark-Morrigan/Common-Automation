#!/usr/bin/env bats
# Unit tests for _run-common.sh, the setup every local runner sources.
# Run with: bats scripts/_run-common.bats
#
# Each case sources it into a fresh bash, since it arms set -e and an EXIT
# trap that would otherwise act on the bats process.

setup() {

    # A full local run exports these into the suites it starts.
    unset COMMON_AUTOMATION_TARGET_REPO COMMON_AUTOMATION_TARGET_REPO_NAMED

    COMMON_SH="${BATS_TEST_DIRNAME}/_run-common.sh"
    COMMON_AUTOMATION_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

# Sources _run-common.sh in a fresh bash, then prints repo_root.
#   source_common_and_print_target
source_common_and_print_target() {

    bash -c 'source "$1"; echo "repo_root=${repo_root}"' _ "${COMMON_SH}"
}

@test "targets Common-Automation itself and names it when no target is given" {

    run source_common_and_print_target

    [ "${status}" -eq 0 ]
    [ "${output}" = "Target repo: ${COMMON_AUTOMATION_ROOT}
repo_root=${COMMON_AUTOMATION_ROOT}" ]
}

@test "targets and names the repo COMMON_AUTOMATION_TARGET_REPO gives" {

    export COMMON_AUTOMATION_TARGET_REPO="${BATS_TEST_TMPDIR}/target"
    run source_common_and_print_target

    [ "${output}" = "Target repo: ${COMMON_AUTOMATION_TARGET_REPO}
repo_root=${COMMON_AUTOMATION_TARGET_REPO}" ]
}

@test "stays quiet when a runner that started it already named the target" {

    export COMMON_AUTOMATION_TARGET_REPO_NAMED=1
    run source_common_and_print_target

    [ "${output}" = "repo_root=${COMMON_AUTOMATION_ROOT}" ]
}

@test "marks the target named for the runners it starts" {

    run bash -c 'source "$1" > /dev/null; bash -c "echo \${COMMON_AUTOMATION_TARGET_REPO_NAMED}"' _ "${COMMON_SH}"

    [ "${output}" = "1" ]
}
