#!/usr/bin/env bats
#
# Tests for fix-trailing-whitespace.sh,
# the repo-wide trim.
#
# Each test drives a throwaway repo in BATS_TEST_TMPDIR,
# since the fix reads its file set out of git.
#
# Every fixture states its whitespace as a printf escape;
# git-fixtures.bash says why.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo

    # shellcheck source=SCRIPTDIR/fix-trailing-whitespace.sh
    source "${BATS_TEST_DIRNAME}/fix-trailing-whitespace.sh"
}

@test "trims every offending tracked file, repo-wide" {

    mkdir nested
    add_tracked_file notes.md 'A line   \n'
    add_tracked_file nested/deep.md 'Deep\t\n'
    add_tracked_file clean.md 'Clean\n'

    run fix_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = 'A line' ]
    [ "$(cat nested/deep.md)" = 'Deep' ]
    [ "${output}" = "$(printf 'trimming trailing whitespace in nested/deep.md\ntrimming trailing whitespace in notes.md')" ]
}

@test "honours a type a tier adds" {

    add_tracked_file build.gradle 'apply plugin: 3   \n'
    WHITESPACE_TRIMMED_TYPES+=('*.gradle')

    run fix_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "$(cat build.gradle)" = 'apply plugin: 3' ]
}

@test "is a silent no-op when nothing offends" {

    add_tracked_file clean.md 'A line\n'
    run fix_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
