#!/usr/bin/env bash
# Writes one log record already shaped by its presenter. Sourced, not executed:
# defines write_presented_log_record.
#
# run_stage shapes each stage's log, but a chain's own lines reach no stage's
# presenter. Written raw, they would show as records among the shaped lines.

# shellcheck source=SCRIPTDIR/resolve-log-presenter.sh
source "${BASH_SOURCE[0]%/*}/resolve-log-presenter.sh"

# Runs the record writer with its arguments, and sends the record it writes
# through the presenter for whoever reads the log, to stderr. Returns the
# presenter's status when the writer succeeded.
#   write_presented_log_record <record writer function> [<role> <text>...]
write_presented_log_record() {

    local log_presenter
    local pipe_statuses=()

    resolve_log_presenter

    # PIPESTATUS is copied whole in one command, since the next resets it. The
    # `|| true` keeps a caller's errexit from ending the script first.
    {
        "$@" 2>&1 >/dev/null | "${log_presenter}" >&2
        pipe_statuses=("${PIPESTATUS[@]}")
    } || true

    if (( pipe_statuses[0] != 0 )); then
        return "${pipe_statuses[0]}"
    fi

    return "${pipe_statuses[1]}"
}
