#!/usr/bin/env bats
# Unit tests for resolve-log-presenter.sh.
# Run with: bats .github/lib/resolve-log-presenter.bats
#
# GITHUB_ACTIONS is set or unset by every case, since bats itself may run
# under GitHub Actions or outside it.

# shellcheck source=SCRIPTDIR/resolve-log-presenter.sh
source "${BATS_TEST_DIRNAME}/resolve-log-presenter.sh"

PRESENTERS_DIR="${BATS_TEST_DIRNAME}/log-records/presenters"

@test "under GitHub Actions, picks the GitHub Actions presenter" {

    export GITHUB_ACTIONS=true

    resolve_log_presenter

    [ "${log_presenter}" = "${PRESENTERS_DIR}/present-log-for-github-actions.sh" ]
}

@test "outside GitHub Actions, picks the terminal presenter" {

    unset GITHUB_ACTIONS

    resolve_log_presenter

    [ "${log_presenter}" = "${PRESENTERS_DIR}/present-log-for-terminal.sh" ]
}

@test "picks the terminal presenter when GITHUB_ACTIONS holds anything but true" {

    export GITHUB_ACTIONS=false

    resolve_log_presenter

    [ "${log_presenter}" = "${PRESENTERS_DIR}/present-log-for-terminal.sh" ]
}

@test "picks a presenter that exists" {

    unset GITHUB_ACTIONS

    resolve_log_presenter

    [ -x "${log_presenter}" ]
}
