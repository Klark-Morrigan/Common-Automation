#!/usr/bin/env bash
# Runs one stage of a chain of scripts with its log framed for whoever reads
# it. Sourced, not executed: defines run_stage.
#
# Under GitHub Actions the stage's log sits in a log group named after its
# file, so a run's log stays readable as stages are added, and is shaped for
# the GitHub Actions log. Outside it the group markers would show as raw lines,
# so the stage gets a section heading instead, and its log is shaped for a
# terminal.
#
# The framing goes to stderr, as the stage's log does: one stream keeps them in
# order, and stdout stays free for the data a stage hands the next.

# shellcheck source=SCRIPTDIR/is-running-in-github-actions.sh
source "${BASH_SOURCE[0]%/*}/is-running-in-github-actions.sh"

# shellcheck source=SCRIPTDIR/log-records/presenters/resolve-log-presenter.sh
source "${BASH_SOURCE[0]%/*}/log-records/presenters/resolve-log-presenter.sh"

# shellcheck source=SCRIPTDIR/print-section-heading.sh
source "${BASH_SOURCE[0]%/*}/print-section-heading.sh"

# shellcheck source=SCRIPTDIR/print-workflow-command.sh
source "${BASH_SOURCE[0]%/*}/print-workflow-command.sh"

# shellcheck source=SCRIPTDIR/run-stage-through-presenter.sh
source "${BASH_SOURCE[0]%/*}/run-stage-through-presenter.sh"

# shellcheck source=SCRIPTDIR/split-stage-exports.sh
source "${BASH_SOURCE[0]%/*}/split-stage-exports.sh"

# Runs the stage script with its arguments, and returns its status. A log
# group is closed even when the stage fails. Each variable named with --export
# reaches that stage alone, as split-stage-exports.sh says.
#   run_stage [--export <variable name>]... <stage script path> [arguments...]
run_stage() {

    local stage_exports=()
    local stage_command=()
    local stage_file_name
    local log_presenter
    local stage_status=0

    split_stage_exports "$@" || return

    stage_file_name="${stage_command[0]##*/}"

    resolve_log_presenter

    if ! is_running_in_github_actions; then

        print_section_heading "${stage_file_name%.sh}" >&2
        run_stage_through_presenter "${log_presenter}" "$@" || stage_status=$?

        return "${stage_status}"
    fi

    print_workflow_command "${WORKFLOW_COMMAND_GROUP}" "${stage_file_name%.sh}" >&2
    run_stage_through_presenter "${log_presenter}" "$@" || stage_status=$?
    print_workflow_command "${WORKFLOW_COMMAND_END_GROUP}" >&2

    return "${stage_status}"
}
