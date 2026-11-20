#!/usr/bin/env bats
#
# Tests for fix-permissions.sh,
# the repo-wide +x heal.
#
# Driven against a throwaway repo in BATS_TEST_TMPDIR,
# passed through CONSUMER_REPO_PATH,
# so the real repo's index is never touched.

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/git-fixtures.bash"

setup() {

    require_git
    SCRIPT="${BATS_TEST_DIRNAME}/fix-permissions.sh"
    new_git_repo

    export CONSUMER_REPO_PATH="${REPO}"
    export COMMON_AUTOMATION_NO_PAUSE=1

    # Stands in for Common-Java's declaration file.
    TIER_FILE="${BATS_TEST_TMPDIR}/tier.sh"
    printf '%s\n' "EXECUTABLE_PATHSPECS+=('gradlew')" > "${TIER_FILE}"
}

@test "heals every script and git hook in the consumer repo" {

    mkdir .githooks
    add_tracked_sh noexec.sh -x
    add_tracked_sh .githooks/pre-commit -x

    run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of noexec.sh)" = "100755" ]
    [ "$(index_mode_of .githooks/pre-commit)" = "100755" ]
    [[ "${output}" == *"Done. Review the changes with: git status"* ]]
}

@test "widens the set with a tier's declaration file" {

    add_tracked_sh gradlew -x

    run bash "${SCRIPT}" "${TIER_FILE}"

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100755" ]
}

@test "skips a tier's declaration file that is absent" {

    add_tracked_sh gradlew -x

    run bash "${SCRIPT}" /nowhere/tier.sh

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100644" ]
}

@test "says there is nothing to fix" {

    add_tracked_sh exec.sh +x

    run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Nothing to fix"* ]]
}
