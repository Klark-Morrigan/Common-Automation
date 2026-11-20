#!/usr/bin/env bats
#
# Tests for
# list-paths-missing-executable-bit.sh,
# the one rule for missing +x.
#
# Each test drives a throwaway repo in BATS_TEST_TMPDIR,
# since the rule reads the git index.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

# "cafe" with an acute e (U+0063 U+0061 U+0066 U+00E9), a name git C-quotes by
# default.
readonly NON_ASCII_SCRIPT='café.sh'

setup() {

    require_git
    new_git_repo

    # Two tracked .sh files differing only in their index mode.
    add_tracked_sh exec.sh +x
    add_tracked_sh noexec.sh -x

    # shellcheck source=SCRIPTDIR/list-paths-missing-executable-bit.sh
    source "${BATS_TEST_DIRNAME}/list-paths-missing-executable-bit.sh"
}

@test "lists only the paths at mode 100644" {

    run list_paths_missing_executable_bit '*.sh'

    [ "${status}" -eq 0 ]
    [ "${output}" = "noexec.sh" ]
}

@test "lists only what the pathspecs name" {

    add_tracked_sh tool.py -x
    run list_paths_missing_executable_bit '*.sh'

    [ "${status}" -eq 0 ]
    [ "${output}" = "noexec.sh" ]
}

@test "checks a named path whatever its extension" {

    add_tracked_sh gradlew -x
    run list_paths_missing_executable_bit gradlew

    [ "${status}" -eq 0 ]
    [ "${output}" = "gradlew" ]
}

@test "names a path holding a space whole" {

    add_tracked_sh 'with space.sh' -x
    run list_paths_missing_executable_bit '*.sh'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'noexec.sh\nwith space.sh')" ]
}

@test "prints a name outside ASCII unquoted" {

    git update-index --chmod=+x noexec.sh
    add_tracked_sh "${NON_ASCII_SCRIPT}" -x

    run list_paths_missing_executable_bit '*.sh'

    [ "${status}" -eq 0 ]
    [ "${output}" = "${NON_ASCII_SCRIPT}" ]
}

@test "scans the whole repo when called from a subfolder" {

    mkdir nested
    cd nested

    run list_paths_missing_executable_bit '*.sh'

    [ "${status}" -eq 0 ]
    [ "${output}" = "noexec.sh" ]
}

@test "reports nothing when every path has +x" {

    git update-index --chmod=+x noexec.sh
    run list_paths_missing_executable_bit '*.sh'

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "refuses to run without a pathspec" {

    run list_paths_missing_executable_bit

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"a pathspec is required"* ]]
}
