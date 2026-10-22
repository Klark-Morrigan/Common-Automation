#!/usr/bin/env bash
# Writes an end record, which closes the open table. A presenter holds a
# table until then, since it cannot pad a column before it has seen every
# cell. Sourced, not executed: defines write_log_table_end.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

#   write_log_table_end
write_log_table_end() {

    write_log_record "${LOG_RECORD_KIND_END}"
}
