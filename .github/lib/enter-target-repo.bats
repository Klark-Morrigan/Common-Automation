#!/usr/bin/env bats
#
# Unit tests for
# enter-target-repo.sh.
#
# Run with:
# bats .github/lib/enter-target-repo.bats

# shellcheck source=SCRIPTDIR/enter-target-repo.sh
source "${BATS_TEST_DIRNAME}/enter-target-repo.sh"

setup() {

    start_dir="${BATS_TEST_TMPDIR}/start"
    target_dir="${BATS_TEST_TMPDIR}/target repo"

    mkdir -p "${start_dir}" "${target_dir}"
    cd "${start_dir}"
}

@test "stays in the current folder when no target repo is named" {

    unset CONSUMER_REPO_PATH
    enter_target_repo

    [ "${PWD}" = "${start_dir}" ]
}

@test "moves into the named target repo, spaces included" {

    export CONSUMER_REPO_PATH="${target_dir}"
    enter_target_repo

    [ "${PWD}" = "${target_dir}" ]
}

@test "fails naming the variable and stays put when the target is no folder" {

    export CONSUMER_REPO_PATH="${BATS_TEST_TMPDIR}/missing"
    run enter_target_repo

    [ "${status}" -eq 1 ]
    [ "${output}" = "::error::CONSUMER_REPO_PATH names ${BATS_TEST_TMPDIR}/missing, which is not a folder." ]
    [ "${PWD}" = "${start_dir}" ]
}
