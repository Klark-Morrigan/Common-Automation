#!/usr/bin/env bats
#
# Tests for
# run-pre-commit-fixes.sh,
# the shared hook body.
#
# Each fix has its own suite;
# what is pinned here is the wiring:
# both run, and a tier's declaration file widens both sets
# when present and is skipped when not.
#
# Every fixture states its whitespace as a printf escape;
# git-fixtures.bash says why.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo

    # shellcheck source=SCRIPTDIR/run-pre-commit-fixes.sh
    source "${BATS_TEST_DIRNAME}/run-pre-commit-fixes.sh"

    # Stands in for Common-Java's declaration files.
    TIER_FILE="${BATS_TEST_TMPDIR}/tier.sh"

    printf '%s\n' \
        "EXECUTABLE_PATHSPECS+=('gradlew')" \
        "WHITESPACE_TRIMMED_TYPES+=('*.gradle')" \
        > "${TIER_FILE}"
}

@test "applies both fixes in one run" {

    add_tracked_sh noexec.sh -x
    add_tracked_file notes.md 'A line   \n'

    run run_pre_commit_fixes

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of noexec.sh)" = "100755" ]
    [ "$(cat notes.md)" = 'A line' ]
}

@test "widens both sets from a tier's declaration file" {

    add_tracked_sh gradlew -x
    add_tracked_file build.gradle 'apply plugin: 3   \n'

    run run_pre_commit_fixes "${TIER_FILE}"

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100755" ]
    [ "$(cat build.gradle)" = 'apply plugin: 3' ]
}

@test "commits fine when a tier's declaration file is absent" {

    add_tracked_sh gradlew -x
    add_tracked_file notes.md 'A line   \n'
    add_tracked_file build.gradle 'apply plugin: 3   \n'

    run run_pre_commit_fixes /nowhere/tier.sh

    [ "${status}" -eq 0 ]

    # The family-wide sets still apply; the tier's own additions simply do not.
    [ "$(cat notes.md)" = 'A line' ]
    [ "$(cat build.gradle)" = "$(printf 'apply plugin: 3   ')" ]
    [ "$(index_mode_of gradlew)" = "100644" ]
}

@test "is a silent no-op when nothing is staged" {

    run run_pre_commit_fixes

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
