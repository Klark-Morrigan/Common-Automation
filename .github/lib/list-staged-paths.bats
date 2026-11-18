#!/usr/bin/env bats
# Tests for list-staged-paths.sh - the staged set both pre-commit fixes read.
# Each test drives a throwaway repo in BATS_TEST_TMPDIR, since the list comes
# out of git's index.

# shellcheck source=SCRIPTDIR/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/test-helpers/git-fixtures.bash"

# "cafe" with an acute e (U+0063 U+0061 U+0066 U+00E9), a name git C-quotes by
# default.
readonly NON_ASCII_NAME='café.md'

setup() {
    require_git

    new_git_repo

    # shellcheck source=SCRIPTDIR/list-staged-paths.sh
    source "${BATS_TEST_DIRNAME}/list-staged-paths.sh"
}

@test "lists an added and a modified path" {
    printf 'one\n' > kept.md
    git add kept.md
    commit_staged

    printf 'two\n' >> kept.md
    printf 'new\n' > added.md
    git add kept.md added.md

    run list_staged_paths
    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'added.md\nkept.md')" ]
}

@test "leaves out a deleted path" {
    printf 'one\n' > gone.md
    git add gone.md
    commit_staged

    git rm -q gone.md

    run list_staged_paths
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "names a file moved without git mv by its new path" {
    printf 'line one\nline two\nline three\n' > before.md
    git add before.md
    commit_staged

    mv before.md after.md
    git add -A
    [[ "$(git diff --cached --name-status)" == R* ]]

    run list_staged_paths
    [ "${status}" -eq 0 ]
    [ "${output}" = "after.md" ]
}

@test "prints a name outside ASCII unquoted" {
    printf 'one\n' > "${NON_ASCII_NAME}"
    git add "${NON_ASCII_NAME}"

    run list_staged_paths
    [ "${status}" -eq 0 ]
    [ "${output}" = "${NON_ASCII_NAME}" ]
}

@test "is a silent no-op when nothing is staged" {
    run list_staged_paths
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
