#!/usr/bin/env bash
# Writes a notice record: a run's outcome, as one line of text. Sourced, not
# executed: defines write_log_notice.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

# Plain words take an empty role.
#   write_log_notice <role> <text> [<role> <text>...]
write_log_notice() {

    write_log_record "${LOG_RECORD_KIND_NOTICE}" "$@"
}
