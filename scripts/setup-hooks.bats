#!/usr/bin/env bats
#
# Tests for setup-hooks.sh,
# the one-time per-clone wiring that points git at .githooks/.
#
# Driven against a throwaway repo in BATS_TEST_TMPDIR,
# passed through CONSUMER_REPO_PATH,
# so the real repo's git config is never touched.

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/git-fixtures.bash"

setup() {

    require_git
    SCRIPT="${BATS_TEST_DIRNAME}/setup-hooks.sh"
    new_git_repo
}

@test "points core.hooksPath at .githooks for the consumer repo" {

    CONSUMER_REPO_PATH="${REPO}" run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(git -C "${REPO}" config core.hooksPath)" = ".githooks" ]
}

@test "announces the configured repo and hooks path" {

    CONSUMER_REPO_PATH="${REPO}" run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Hooks configured for ${REPO}. core.hooksPath=.githooks"* ]]
}

@test "says there is no need on a second run" {

    CONSUMER_REPO_PATH="${REPO}" bash "${SCRIPT}"

    CONSUMER_REPO_PATH="${REPO}" run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"No need - hooks have been configured already"* ]]
    [ "$(git -C "${REPO}" config core.hooksPath)" = ".githooks" ]
}

@test "names a hook that lacks +x in the index" {

    mkdir .githooks
    add_tracked_sh .githooks/pre-commit -x

    CONSUMER_REPO_PATH="${REPO}" run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"These hooks lack +x"*".githooks/pre-commit"* ]]
}

@test "says nothing of hooks that carry +x" {

    mkdir .githooks
    add_tracked_sh .githooks/pre-commit +x

    CONSUMER_REPO_PATH="${REPO}" run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" != *"lack +x"* ]]
}
