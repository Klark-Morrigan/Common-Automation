#!/usr/bin/env bash
# Writes an error record: a failure, as one line of text. Sourced, not
# executed: defines write_log_error.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

# Plain words take an empty role.
#   write_log_error <role> <text> [<role> <text>...]
write_log_error() {

    write_log_record "${LOG_RECORD_KIND_ERROR}" "$@"
}
