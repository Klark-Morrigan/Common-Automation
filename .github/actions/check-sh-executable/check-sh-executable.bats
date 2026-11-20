#!/usr/bin/env bats
#
# Tests for check-sh-executable.sh,
# the +x gate over tracked .sh files.
#
# Each test runs against a throwaway repo in BATS_TEST_TMPDIR,
# never the real repo.
# What counts as missing +x is the detector's,
# tested in
# lib/fixes/list-paths-missing-executable-bit.bats.

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/git-fixtures.bash"

setup() {

    require_git
    SCRIPT="${BATS_TEST_DIRNAME}/check-sh-executable.sh"
    new_git_repo

    # Two tracked .sh files differing only in their index mode.
    add_tracked_sh exec.sh +x
    add_tracked_sh noexec.sh -x
}

@test "gate exits 1, names the offender, and prints the fix command" {

    run bash "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"::error::"*"missing +x"* ]]
    [[ "${output}" == *"noexec.sh"* ]]
    [[ "${output}" == *"git update-index --chmod=+x"* ]]
}

@test "gate exits 0 when every tracked .sh has +x" {

    git update-index --chmod=+x noexec.sh
    run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
}

@test "gate holds only .sh files to the bar" {

    git update-index --chmod=+x noexec.sh
    add_tracked_sh gradlew -x
    run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
}

@test "gate scans the whole repo when run from a subfolder" {

    mkdir nested
    cd nested
    run bash "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"noexec.sh"* ]]
}
