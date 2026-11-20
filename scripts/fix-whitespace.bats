#!/usr/bin/env bats
#
# Tests for fix-whitespace.sh,
# the repo-wide trim.
#
# Driven against a throwaway repo in BATS_TEST_TMPDIR,
# passed through CONSUMER_REPO_PATH,
# so the real repo's files are never touched.
#
# Every fixture states its whitespace as a printf escape;
# git-fixtures.bash says why.

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/git-fixtures.bash"

setup() {

    require_git
    SCRIPT="${BATS_TEST_DIRNAME}/fix-whitespace.sh"
    new_git_repo

    export CONSUMER_REPO_PATH="${REPO}"
    export COMMON_AUTOMATION_NO_PAUSE=1

    # Stands in for Common-Java's declaration file.
    TIER_FILE="${BATS_TEST_TMPDIR}/tier.sh"
    printf '%s\n' "WHITESPACE_TRIMMED_TYPES+=('*.gradle')" > "${TIER_FILE}"
}

@test "trims every offending Markdown file in the consumer repo" {

    add_tracked_file notes.md 'A line   \n'

    run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = 'A line' ]
    [[ "${output}" == *"Done. Review the changes with: git diff"* ]]
}

@test "widens the set with a tier's declaration file" {

    add_tracked_file build.gradle 'apply plugin: 3   \n'

    run bash "${SCRIPT}" "${TIER_FILE}"

    [ "${status}" -eq 0 ]
    [ "$(cat build.gradle)" = 'apply plugin: 3' ]
}

@test "skips a tier's declaration file that is absent" {

    add_tracked_file build.gradle 'apply plugin: 3   \n'

    run bash "${SCRIPT}" /nowhere/tier.sh

    [ "${status}" -eq 0 ]
    [ "$(cat build.gradle)" = "$(printf 'apply plugin: 3   ')" ]
}

@test "says there is nothing to fix" {

    add_tracked_file clean.md 'A line\n'

    run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Nothing to fix"* ]]
}
