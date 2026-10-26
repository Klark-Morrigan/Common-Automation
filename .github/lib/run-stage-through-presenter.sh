#!/usr/bin/env bash
# Runs one stage of a chain of scripts with its log shaped by a presenter.
# Sourced, not executed: defines run_stage_through_presenter.
#
# The stage's stderr goes through the presenter, one of
# log-records/presenters/. Its stdout leaves through fd 3, around the pipe, so
# the data it hands the next stage never reaches the presenter.
#
# The stage runs with LOG_RECORDS=true, so workflow-commands.sh writes its
# annotations as records the presenter shapes.

# Runs the stage script with its arguments, and returns its status, not the
# presenter's.
#   run_stage_through_presenter <presenter path> <stage script path> [arguments...]
run_stage_through_presenter() {

    local presenter="$1"
    local stage_script="$2"
    local stage_status=0

    shift 2

    # The `|| true` keeps a caller's errexit from ending the script before the
    # status is returned; PIPESTATUS reads the stage's own status whether or
    # not the caller set pipefail.
    {
        LOG_RECORDS=true "${stage_script}" "$@" 2>&1 1>&3 3>&- | "${presenter}" >&2 3>&-
        stage_status="${PIPESTATUS[0]}"
    } 3>&1 || true

    return "${stage_status}"
}
