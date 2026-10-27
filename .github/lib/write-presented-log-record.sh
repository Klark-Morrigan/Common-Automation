#!/usr/bin/env bash
# Writes one log record already shaped by its presenter. Sourced, not executed:
# defines write_presented_log_record.
#
# run_stage shapes each stage's log, but a chain's own lines reach no stage's
# presenter. Written raw, they would show as records among the shaped lines.

# shellcheck source=SCRIPTDIR/log-records/presenters/resolve-log-presenter.sh
source "${BASH_SOURCE[0]%/*}/log-records/presenters/resolve-log-presenter.sh"

# shellcheck source=SCRIPTDIR/run-stage-through-presenter.sh
source "${BASH_SOURCE[0]%/*}/run-stage-through-presenter.sh"

# Runs the record writer with its arguments as a stage runs, so its record goes
# through the presenter run_stage would pick, and a failure is logged and
# returned as a stage's is.
#   write_presented_log_record <record writer function> [<role> <text>...]
write_presented_log_record() {

    local log_presenter

    resolve_log_presenter
    run_stage_through_presenter "${log_presenter}" "$@"
}
