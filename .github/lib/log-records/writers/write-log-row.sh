#!/usr/bin/env bash
# Writes a row record: one row of the open table. Sourced, not executed:
# defines write_log_row.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

# One role and text pair per cell, in column order.
#   write_log_row <role> <cell text> [<role> <cell text>...]
write_log_row() {

    write_log_record "${LOG_RECORD_KIND_ROW}" "$@"
}
