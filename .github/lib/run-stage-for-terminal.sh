#!/usr/bin/env bash
# Runs one stage of a chain of scripts with its log shaped for a person at a
# terminal. Sourced, not executed: defines run_stage_for_terminal.
#
# The stage's stderr goes through the terminal presenter, beside this file in
# log-records/presenters/. Its stdout leaves through fd 3, around the pipe, so
# the data it hands the next stage never reaches the presenter.

# Runs the stage script with its arguments, and returns its status, not the
# presenter's.
#   run_stage_for_terminal <stage script path> [arguments...]
run_stage_for_terminal() {

    local stage_script="$1"
    local presenter="${BASH_SOURCE[0]%/*}/log-records/presenters/present-log-for-terminal.sh"
    local stage_status=0

    shift

    # The `|| true` keeps a caller's errexit from ending the script before the
    # status is returned; PIPESTATUS reads the stage's own status whether or
    # not the caller set pipefail.
    {
        "${stage_script}" "$@" 2>&1 1>&3 3>&- | "${presenter}" >&2 3>&-
        stage_status="${PIPESTATUS[0]}"
    } 3>&1 || true

    return "${stage_status}"
}
