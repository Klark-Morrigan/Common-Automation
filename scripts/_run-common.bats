#!/usr/bin/env bats
# Unit tests for _run-common.sh, the setup every local runner sources.
# Run with: bats scripts/_run-common.bats
#
# Each case sources it into a fresh bash, since it arms set -e and an EXIT
# trap that would otherwise act on the bats process.

setup() {

    # A full local run exports these into the suites it starts.
    unset CONSUMER_REPO_PATH CONSUMER_REPO_PATH_NAMED

    COMMON_SH="${BATS_TEST_DIRNAME}/_run-common.sh"
    COMMON_AUTOMATION_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

# Sources _run-common.sh in a fresh bash, then prints repo_root.
#   source_common_and_print_repo_root
source_common_and_print_repo_root() {

    bash -c 'source "$1"; echo "repo_root=${repo_root}"' _ "${COMMON_SH}"
}

@test "works on Common-Automation itself and names it when no consumer is given" {

    run source_common_and_print_repo_root

    [ "${status}" -eq 0 ]
    [ "${output}" = "Consumer repo: ${COMMON_AUTOMATION_ROOT}
repo_root=${COMMON_AUTOMATION_ROOT}" ]
}

@test "works on and names the repo CONSUMER_REPO_PATH gives" {

    export CONSUMER_REPO_PATH="${BATS_TEST_TMPDIR}/consumer"
    run source_common_and_print_repo_root

    [ "${output}" = "Consumer repo: ${CONSUMER_REPO_PATH}
repo_root=${CONSUMER_REPO_PATH}" ]
}

@test "stays quiet when a runner that started it already named the consumer" {

    export CONSUMER_REPO_PATH_NAMED=1
    run source_common_and_print_repo_root

    [ "${output}" = "repo_root=${COMMON_AUTOMATION_ROOT}" ]
}

@test "marks the consumer named for the runners it starts" {

    run bash -c 'source "$1" > /dev/null; bash -c "echo \${CONSUMER_REPO_PATH_NAMED}"' _ "${COMMON_SH}"

    [ "${output}" = "1" ]
}
