#!/usr/bin/env bash
# Tells a run under GitHub Actions from any other. Sourced, not executed:
# defines is_running_in_github_actions.
#
# The runner sets GITHUB_ACTIONS to "true". Anything else, unset included, is a
# run outside it, such as a person's terminal.

# Returns 0 under GitHub Actions, 1 anywhere else.
#   is_running_in_github_actions
is_running_in_github_actions() {

    [[ "${GITHUB_ACTIONS:-}" == "true" ]]
}
