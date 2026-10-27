#!/usr/bin/env bats
# Unit tests for is-running-in-github-actions.sh.
# Run with: bats .github/lib/is-running-in-github-actions.bats
#
# GITHUB_ACTIONS is set or unset by every case, since bats itself may run
# under GitHub Actions or outside it.

# run ! arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/is-running-in-github-actions.sh
source "${BATS_TEST_DIRNAME}/is-running-in-github-actions.sh"

@test "holds when GITHUB_ACTIONS is true" {

    export GITHUB_ACTIONS=true

    run is_running_in_github_actions

    [ "${status}" -eq 0 ]
}

@test "fails when GITHUB_ACTIONS is unset" {

    unset GITHUB_ACTIONS

    run ! is_running_in_github_actions
}

@test "fails when GITHUB_ACTIONS holds anything but true" {

    export GITHUB_ACTIONS=false

    run ! is_running_in_github_actions
}
