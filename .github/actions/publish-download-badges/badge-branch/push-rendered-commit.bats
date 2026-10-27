#!/usr/bin/env bats
# Unit tests for push-rendered-commit.sh.
# Run with: bats .github/actions/publish-download-badges/badge-branch/push-rendered-commit.bats
#
# A local bare repo stands in for the remote, reached by its path, which
# ignores HTTP headers, so the credential goes unread. The
# rendered commit sits in a scratch repo, the working directory each case
# pushes from. read_remote_branch_commit is the real one: a push that reports
# a failure is judged by what it reads back.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/push-failure-fixtures.bash
source "${BATS_TEST_DIRNAME}/push-failure-fixtures.bash"

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/git-fixtures.bash"

# shellcheck source=SCRIPTDIR/push-rendered-commit.sh
source "${BATS_TEST_DIRNAME}/push-rendered-commit.sh"

BRANCH_REF="refs/heads/badges"
CREDENTIAL="test-credential"

setup() {

    require_git
    new_bare_remote

    # A config of the test's own, so the host's settings cannot reach git.
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL="${BATS_TEST_TMPDIR}/gitconfig"

    git config --file "${GIT_CONFIG_GLOBAL}" user.name "Test"
    git config --file "${GIT_CONFIG_GLOBAL}" user.email "test@example.com"

    new_git_repo
    PUBLISHED_COMMIT="$(commit_figures 44)"
    RENDERED_COMMIT="$(commit_figures 45)"
}

# Commits a figure in the scratch repo and prints the commit.
#   commit_figures <figure>
commit_figures() {

    printf '%s\n' "$1" > downloads.json
    git add downloads.json
    git commit -qm "figures $1"
    git rev-parse HEAD
}

read_branch_commit() {

    git -C "${REMOTE}" rev-parse "${BRANCH_REF}"
}

push_rendered() {

    run --separate-stderr push_rendered_commit "${REMOTE}" "${BRANCH_REF}" "$1" "${RENDERED_COMMIT}" "${CREDENTIAL}"
}

@test "creates the branch when the lease is empty" {

    push_rendered ""

    [ "${status}" -eq 0 ]
    [ "$(read_branch_commit)" = "${RENDERED_COMMIT}" ]
}

@test "replaces the branch when it still holds the commit the run read" {

    git push -q "${REMOTE}" "${PUBLISHED_COMMIT}:${BRANCH_REF}"

    push_rendered "${PUBLISHED_COMMIT}"

    [ "${status}" -eq 0 ]
    [ "$(read_branch_commit)" = "${RENDERED_COMMIT}" ]
}

@test "refuses to replace a branch that moved after the run read it" {

    git push -q "${REMOTE}" "${PUBLISHED_COMMIT}:${BRANCH_REF}"

    push_rendered ""

    [ "${status}" -ne 0 ]
    [ "$(read_branch_commit)" = "${PUBLISHED_COMMIT}" ]
}

@test "counts a push that landed but reported a failure as pushed, and logs it" {

    install_failing_push_git landed

    push_rendered ""

    [ "${status}" -eq 0 ]
    [ "$(read_branch_commit)" = "${RENDERED_COMMIT}" ]
    [ "${stderr_lines[-1]}" = "$(write_log_message \
        "" "The push reported a failure, but " id "badges" "" " already holds " id "${RENDERED_COMMIT}" "" "." \
        2>&1)" ]
}

@test "returns the push's own failure when the branch did not move" {

    install_failing_push_git

    push_rendered ""

    [ "${status}" -eq 128 ]
    [ -z "$(git -C "${REMOTE}" for-each-ref "${BRANCH_REF}")" ]
}
