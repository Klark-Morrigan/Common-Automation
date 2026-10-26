#!/usr/bin/env bash
# Runs one stage of a chain of scripts with its log framed for whoever reads
# it. Sourced, not executed: defines run_stage.
#
# Under Actions the stage's log sits in a log group named after its file, so a
# run's log stays readable as stages are added, and is shaped for the Actions
# log. Outside Actions the group markers would show as raw lines, so the stage
# gets a section heading instead, and its log is shaped for a terminal.
#
# The framing goes to stderr, as the stage's log does: one stream keeps them in
# order, and stdout stays free for the data a stage hands the next.

# shellcheck source=SCRIPTDIR/print-section-heading.sh
source "${BASH_SOURCE[0]%/*}/print-section-heading.sh"

# shellcheck source=SCRIPTDIR/run-stage-through-presenter.sh
source "${BASH_SOURCE[0]%/*}/run-stage-through-presenter.sh"

# Runs the stage script with its arguments, and returns its status. A log
# group is closed even when the stage fails.
#   run_stage <stage script path> [arguments...]
run_stage() {

    local stage_file_name="${1##*/}"
    local presenters_dir="${BASH_SOURCE[0]%/*}/log-records/presenters"
    local stage_status=0

    if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then

        print_section_heading "${stage_file_name%.sh}" >&2
        run_stage_through_presenter "${presenters_dir}/present-log-for-terminal.sh" "$@" || stage_status=$?

        return "${stage_status}"
    fi

    echo "::group::${stage_file_name%.sh}" >&2
    run_stage_through_presenter "${presenters_dir}/present-log-for-github-actions.sh" "$@" || stage_status=$?
    echo "::endgroup::" >&2

    return "${stage_status}"
}
