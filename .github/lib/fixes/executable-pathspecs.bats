#!/usr/bin/env bats
#
# Tests for executable-pathspecs.sh,
# the family-wide +x set.
#
# The set is git pathspecs,
# so each test asks git which tracked paths it names,
# in a throwaway repo in BATS_TEST_TMPDIR.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo
    mkdir -p .githooks nested
}

@test "names every .sh at any depth and every git hook" {

    add_tracked_file run.sh 'echo\n'
    add_tracked_file nested/deep.sh 'echo\n'
    add_tracked_file .githooks/pre-commit 'echo\n'
    add_tracked_file README.md 'Text\n'

    # shellcheck source=SCRIPTDIR/executable-pathspecs.sh
    source "${BATS_TEST_DIRNAME}/executable-pathspecs.sh"
    run git ls-files -- "${EXECUTABLE_PATHSPECS[@]}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf '.githooks/pre-commit\nnested/deep.sh\nrun.sh')" ]
}

@test "leaves a dotfile beside the git hooks out" {

    add_tracked_file .githooks/pre-commit 'echo\n'
    add_tracked_file .githooks/.gitignore 'local-hook\n'

    # shellcheck source=SCRIPTDIR/executable-pathspecs.sh
    source "${BATS_TEST_DIRNAME}/executable-pathspecs.sh"
    run git ls-files -- "${GIT_HOOK_PATHSPECS[@]}"

    [ "${status}" -eq 0 ]
    [ "${output}" = ".githooks/pre-commit" ]
}

@test "keeps a tier's paths when sourced again" {

    # shellcheck source=SCRIPTDIR/executable-pathspecs.sh
    source "${BATS_TEST_DIRNAME}/executable-pathspecs.sh"
    EXECUTABLE_PATHSPECS+=('gradlew')

    # shellcheck source=SCRIPTDIR/executable-pathspecs.sh
    source "${BATS_TEST_DIRNAME}/executable-pathspecs.sh"

    [ "${EXECUTABLE_PATHSPECS[*]}" = '*.sh .githooks/* :(exclude).githooks/.* gradlew' ]
}
