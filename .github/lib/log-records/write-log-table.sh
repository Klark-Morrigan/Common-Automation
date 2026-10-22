#!/usr/bin/env bash
# Writes a table record, which opens a table and names its columns. Sourced,
# not executed: defines write_log_table.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

# One role and name pair per column; a plain name takes an empty role.
#   write_log_table <role> <column name> [<role> <column name>...]
write_log_table() {

    write_log_record "${LOG_RECORD_KIND_TABLE}" "$@"
}
