#!/usr/bin/env bats
#
# Tests for
# set-executable-bits.sh,
# which sets +x in the index on the paths given.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo

    add_tracked_sh first.sh -x
    add_tracked_sh 'second one.sh' -x
    add_tracked_sh spared.sh -x

    # shellcheck source=SCRIPTDIR/set-executable-bits.sh
    source "${BATS_TEST_DIRNAME}/set-executable-bits.sh"
}

@test "sets +x on every path given and names each" {

    run set_executable_bits first.sh 'second one.sh'

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of first.sh)" = "100755" ]
    [ "$(index_mode_of 'second one.sh')" = "100755" ]
    [ "${output}" = "$(printf 'fixing +x on first.sh\nfixing +x on second one.sh')" ]
}

@test "leaves a path it is not given alone" {

    run set_executable_bits first.sh

    [ "${status}" -eq 0 ]
    [ "$(index_mode_of spared.sh)" = "100644" ]
}

@test "reads the paths from the repo top when called from a subfolder" {

    mkdir nested
    cd nested

    run set_executable_bits first.sh

    [ "${status}" -eq 0 ]
    [ "$(cd .. && index_mode_of first.sh)" = "100755" ]
}
