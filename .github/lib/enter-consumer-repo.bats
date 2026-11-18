#!/usr/bin/env bats
#
# Unit tests for
# enter-consumer-repo.sh.
#
# Run with:
# bats .github/lib/enter-consumer-repo.bats

# shellcheck source=SCRIPTDIR/enter-consumer-repo.sh
source "${BATS_TEST_DIRNAME}/enter-consumer-repo.sh"

setup() {

    start_dir="${BATS_TEST_TMPDIR}/start"
    consumer_dir="${BATS_TEST_TMPDIR}/consumer repo"

    mkdir -p "${start_dir}" "${consumer_dir}"
    cd "${start_dir}"
}

@test "stays in the current folder when no consumer repo is named" {

    unset CONSUMER_REPO_PATH
    enter_consumer_repo

    [ "${PWD}" = "${start_dir}" ]
}

@test "moves into the named consumer repo, spaces included" {

    export CONSUMER_REPO_PATH="${consumer_dir}"
    enter_consumer_repo

    [ "${PWD}" = "${consumer_dir}" ]
}

@test "fails naming the variable and stays put when the consumer is no folder" {

    export CONSUMER_REPO_PATH="${BATS_TEST_TMPDIR}/missing"
    run enter_consumer_repo

    [ "${status}" -eq 1 ]
    [ "${output}" = "::error::CONSUMER_REPO_PATH names ${BATS_TEST_TMPDIR}/missing, which is not a folder." ]
    [ "${PWD}" = "${start_dir}" ]
}
