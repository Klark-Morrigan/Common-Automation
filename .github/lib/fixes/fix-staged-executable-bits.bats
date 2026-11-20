#!/usr/bin/env bats
#
# Tests for fix-staged-executable-bits.sh,
# the pre-commit fix for +x.
#
# Each test drives a throwaway repo in BATS_TEST_TMPDIR,
# since the fix reads what is staged out of git.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo

    # shellcheck source=SCRIPTDIR/fix-staged-executable-bits.sh
    source "${BATS_TEST_DIRNAME}/fix-staged-executable-bits.sh"
}

@test "sets +x on a staged script missing it" {

    add_tracked_sh noexec.sh -x
    run fix_staged_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of noexec.sh)" = "100755" ]
    [ "${output}" = "fixing +x on noexec.sh" ]
}

@test "sets +x on a staged git hook missing it" {

    mkdir .githooks
    add_tracked_sh .githooks/pre-commit -x

    run fix_staged_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of .githooks/pre-commit)" = "100755" ]
}

@test "restores +x on a script moved without git mv" {

    add_tracked_sh before.sh +x
    commit_staged

    # A plain move stages a new index entry, which a Windows checkout gives no +x.
    # Pinned here so the fixture does not depend on core.fileMode.
    mv before.sh after.sh
    git add -A
    git update-index --chmod=-x after.sh

    [[ "$(git diff --cached --name-status)" == R* ]]

    run fix_staged_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of after.sh)" = "100755" ]
}

@test "leaves a script missing +x alone when it is not staged" {

    add_tracked_sh committed.sh -x
    commit_staged
    add_tracked_sh staged.sh -x

    run fix_staged_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of staged.sh)" = "100755" ]
    [ "$(index_mode_of committed.sh)" = "100644" ]
}

@test "leaves a staged file outside the executable set alone" {

    add_tracked_sh gradlew -x
    run fix_staged_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100644" ]
}

@test "honours a path a tier adds to the set" {

    add_tracked_sh gradlew -x
    EXECUTABLE_PATHSPECS+=('gradlew')

    run fix_staged_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100755" ]
}

@test "is a silent no-op when nothing is staged" {

    run fix_staged_executable_bits

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
