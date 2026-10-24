#!/usr/bin/env bats
# Unit tests for describe-git-checkout.sh.
# Run with: bats .github/lib/describe-git-checkout.bats
#
# Runs real git against throwaway repositories, since the function's whole
# job is reading git's state.

# shellcheck source=SCRIPTDIR/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/test-helpers/git-fixtures.bash"

setup() {

    require_git

    # shellcheck source=SCRIPTDIR/describe-git-checkout.sh
    source "${BATS_TEST_DIRNAME}/describe-git-checkout.sh"

    new_git_repo
    git checkout -q -b main
}

# Commits one file, so the repository has a head.
commit_file() {

    printf 'content\n' > tracked.txt
    git add tracked.txt
    git -c user.name=test -c user.email=test@example.com commit -q -m "add tracked.txt"
}

@test "names the branch and the commit of a clean checkout" {

    commit_file

    local expected_commit
    expected_commit="$(git rev-parse --short HEAD)"

    run describe_git_checkout "${REPO}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${REPO}: main at ${expected_commit}" ]
}

@test "says when the tree holds uncommitted changes" {

    commit_file
    printf 'edited\n' > tracked.txt

    run describe_git_checkout "${REPO}"

    [[ "${output}" == *", with uncommitted changes" ]]
}

@test "counts an untracked file as an uncommitted change" {

    commit_file
    printf 'new\n' > untracked.txt

    run describe_git_checkout "${REPO}"

    [[ "${output}" == *", with uncommitted changes" ]]
}

@test "reads a detached head as detached" {

    commit_file

    local expected_commit
    expected_commit="$(git rev-parse --short HEAD)"

    git checkout -q --detach

    run describe_git_checkout "${REPO}"

    [ "${output}" = "${REPO}: detached at ${expected_commit}" ]
}

@test "reads a repository with no commit as such" {

    run describe_git_checkout "${REPO}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${REPO}: main, no commits yet" ]
}

@test "reads a directory outside any repository as not a checkout" {

    local outside="${BATS_TEST_TMPDIR}/outside"
    mkdir -p "${outside}"

    GIT_CEILING_DIRECTORIES="${BATS_TEST_TMPDIR}" run describe_git_checkout "${outside}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${outside}: not a git checkout" ]
}
