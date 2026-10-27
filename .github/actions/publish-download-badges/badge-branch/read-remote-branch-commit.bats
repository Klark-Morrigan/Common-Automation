#!/usr/bin/env bats
# Unit tests for read-remote-branch-commit.sh.
# Run with: bats .github/actions/publish-download-badges/badge-branch/read-remote-branch-commit.bats
#
# A local bare repo stands in for the remote, reached by its path. A local
# remote ignores HTTP headers, so the credential goes unread;
# run-git-with-token.bats holds what git is handed.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/git-fixtures.bash"

# shellcheck source=SCRIPTDIR/read-remote-branch-commit.sh
source "${BATS_TEST_DIRNAME}/read-remote-branch-commit.sh"

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
    git commit -q --allow-empty -m "figures"
    COMMIT="$(git rev-parse HEAD)"
}

@test "prints the commit the branch points at" {

    git push -q "${REMOTE}" "HEAD:${BRANCH_REF}"

    run --separate-stderr read_remote_branch_commit "${REMOTE}" "${BRANCH_REF}" "${CREDENTIAL}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${COMMIT}" ]
}

@test "prints nothing when the branch does not exist" {

    run --separate-stderr read_remote_branch_commit "${REMOTE}" "${BRANCH_REF}" "${CREDENTIAL}"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "ignores a ref whose tail matches the branch's" {

    # ls-remote matches the pattern against the tail of each ref.
    git push -q "${REMOTE}" "HEAD:refs/heads/team/${BRANCH_REF}"

    run --separate-stderr read_remote_branch_commit "${REMOTE}" "${BRANCH_REF}" "${CREDENTIAL}"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "fails when the remote cannot be read" {

    run --separate-stderr read_remote_branch_commit "${BATS_TEST_TMPDIR}/missing.git" "${BRANCH_REF}" "${CREDENTIAL}"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
}
