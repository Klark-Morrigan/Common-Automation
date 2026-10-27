#!/usr/bin/env bats
# Unit tests for resolve-log-presenter.sh.
# Run with: bats .github/lib/log-records/presenters/resolve-log-presenter.bats
#
# is_running_in_github_actions is replaced per case, after the file is
# sourced, so each case picks the runner it stands in.

# shellcheck source=SCRIPTDIR/resolve-log-presenter.sh
source "${BATS_TEST_DIRNAME}/resolve-log-presenter.sh"

PRESENTERS_DIR="${BATS_TEST_DIRNAME}"

# Stands in for a run under GitHub Actions.
stand_in_github_actions() {

    is_running_in_github_actions() {

        return 0
    }
}

# Stands in for a run outside GitHub Actions.
stand_in_terminal() {

    is_running_in_github_actions() {

        return 1
    }
}

@test "under GitHub Actions, picks the GitHub Actions presenter" {

    stand_in_github_actions

    resolve_log_presenter

    [ "${log_presenter}" = "${PRESENTERS_DIR}/present-log-for-github-actions.sh" ]
}

@test "outside GitHub Actions, picks the terminal presenter" {

    stand_in_terminal

    resolve_log_presenter

    [ "${log_presenter}" = "${PRESENTERS_DIR}/present-log-for-terminal.sh" ]
}

@test "picks presenters that exist" {

    stand_in_github_actions
    resolve_log_presenter

    [ -x "${log_presenter}" ]

    stand_in_terminal
    resolve_log_presenter

    [ -x "${log_presenter}" ]
}
