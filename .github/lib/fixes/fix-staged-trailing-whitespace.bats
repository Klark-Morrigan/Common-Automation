#!/usr/bin/env bats
#
# Tests for fix-staged-trailing-whitespace.sh,
# the pre-commit fix for whitespace.
#
# Each test drives a throwaway repo in BATS_TEST_TMPDIR,
# since the fix reads what is staged out of git.
#
# Every fixture states its whitespace as a printf escape;
# git-fixtures.bash says why.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo

    # shellcheck source=SCRIPTDIR/fix-staged-trailing-whitespace.sh
    source "${BATS_TEST_DIRNAME}/fix-staged-trailing-whitespace.sh"
}

@test "trims a staged file and re-stages it" {

    add_tracked_file notes.md 'A line   \n'
    run fix_staged_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = 'A line' ]

    # Nothing left unstaged: the trim went into the index, not beside it.
    git diff --quiet -- notes.md
}

@test "trims a file moved without git mv and edited" {

    add_tracked_file before.md 'One\nTwo\nThree\nFour\nFive\n'
    commit_staged

    mv before.md after.md
    printf 'One\nTwo\nThree\nFour\nFive   \n' > after.md
    git add -A

    [[ "$(git diff --cached --name-status)" == R* ]]

    run fix_staged_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "$(git show :after.md)" = "$(printf 'One\nTwo\nThree\nFour\nFive')" ]
}

@test "leaves a partly staged file for its author" {

    add_tracked_file notes.md 'Committed\n'
    commit_staged

    printf 'Staged   \n' > notes.md
    git add notes.md
    printf 'Staged   \nUnstaged\n' > notes.md

    run fix_staged_trailing_whitespace

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"it has unstaged changes"* ]]

    # Untouched on both sides: the working tree keeps the author's line,
    # and the index keeps the whitespace rather than gaining the unstaged hunk.
    [ "$(cat notes.md)" = "$(printf 'Staged   \nUnstaged')" ]
    [ "$(git show :notes.md)" = "$(printf 'Staged   ')" ]
}

@test "leaves an offender that is not staged alone" {

    add_tracked_file committed.md 'Committed   \n'
    commit_staged
    add_tracked_file staged.md 'Staged\n'

    run fix_staged_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "$(cat committed.md)" = "$(printf 'Committed   ')" ]
}

@test "leaves a file that a bracket in a staged name would match alone" {

    # As a glob, a[1].md would also match a1.md.
    add_tracked_file a1.md 'Neighbour   \n'
    commit_staged
    add_tracked_file 'a[1].md' 'Staged   \n'

    run fix_staged_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "$(cat 'a[1].md')" = 'Staged' ]
    [ "$(cat a1.md)" = "$(printf 'Neighbour   ')" ]
    [ -z "$(git diff --cached --name-only -- a1.md)" ]
}

@test "is a silent no-op when nothing is staged" {

    run fix_staged_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
