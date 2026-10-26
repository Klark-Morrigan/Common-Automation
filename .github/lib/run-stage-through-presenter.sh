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
#
# A failure is logged here, after the pipe, straight to stderr: a stage that
# crashed may have logged nothing, and a presenter that died took the rest of
# the stage's log with it.

# shellcheck source=SCRIPTDIR/workflow-commands.sh
source "${BASH_SOURCE[0]%/*}/workflow-commands.sh"

# Runs the stage script with its arguments. Returns the stage's status, or the
# presenter's when only the presenter failed, so a lost log never passes as a
# clean run.
#   run_stage_through_presenter <presenter path> <stage script path> [arguments...]
run_stage_through_presenter() {

    local presenter="$1"
    local stage_script="$2"
    local stage_file_name="${2##*/}"
    local pipe_statuses=()
    local stage_status
    local presenter_status

    shift 2

    # The `|| true` keeps a caller's errexit from ending the script before the
    # status is returned; PIPESTATUS reads each side's own status whether or
    # not the caller set pipefail. It is copied whole in one command, since the
    # next command resets it.
    {
        LOG_RECORDS=true "${stage_script}" "$@" 2>&1 1>&3 3>&- | "${presenter}" >&2 3>&-
        pipe_statuses=("${PIPESTATUS[@]}")
    } 3>&1 || true

    stage_status="${pipe_statuses[0]}"
    presenter_status="${pipe_statuses[1]}"

    if (( stage_status != 0 )); then
        echo "${stage_file_name%.sh} failed with exit status ${stage_status}." >&2
    fi

    if (( presenter_status != 0 )); then
        log_error "the log presenter ${presenter##*/} exited ${presenter_status}" \
            "while ${stage_file_name%.sh} ran; that stage's log may be incomplete."
    fi

    if (( stage_status == 0 )); then
        return "${presenter_status}"
    fi

    return "${stage_status}"
}
