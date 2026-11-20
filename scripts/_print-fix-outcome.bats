#!/usr/bin/env bats
#
# Tests for
# _print-fix-outcome.sh,
# the report every manual fix runner closes with.

setup() {

    # shellcheck source=SCRIPTDIR/_print-fix-outcome.sh
    source "${BATS_TEST_DIRNAME}/_print-fix-outcome.sh"
}

@test "prints what the fix changed and how to review it" {

    run print_fix_outcome 'fixing +x on run.sh' 'git status' 'Nothing to fix.'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'fixing +x on run.sh\nDone. Review the changes with: git status')" ]
}

@test "prints the clean message when the fix changed nothing" {

    run print_fix_outcome '' 'git status' 'Nothing to fix.'

    [ "${status}" -eq 0 ]
    [ "${output}" = 'Nothing to fix.' ]
}
