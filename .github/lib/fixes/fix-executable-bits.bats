#!/usr/bin/env bats
#
# Tests for fix-executable-bits.sh,
# the repo-wide +x heal.
#
# Each test drives a throwaway repo in BATS_TEST_TMPDIR,
# since the fix reads and writes the git index.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo
    add_tracked_sh noexec.sh -x

    # shellcheck source=SCRIPTDIR/fix-executable-bits.sh
    source "${BATS_TEST_DIRNAME}/fix-executable-bits.sh"
}

@test "sets +x on every script and git hook missing it, repo-wide" {

    mkdir .githooks
    add_tracked_sh .githooks/pre-commit -x
    add_tracked_file .githooks/.gitignore 'local-hook\n'
    commit_staged

    run fix_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of noexec.sh)" = "100755" ]
    [ "$(index_mode_of .githooks/pre-commit)" = "100755" ]
    [ "$(index_mode_of .githooks/.gitignore)" = "100644" ]
}

@test "honours a path a tier adds to the set" {

    add_tracked_sh gradlew -x
    EXECUTABLE_PATHSPECS+=('gradlew')

    run fix_executable_bits

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100755" ]
}

@test "is a silent no-op when nothing is missing +x" {

    git update-index --chmod=+x noexec.sh
    run fix_executable_bits

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
