#!/usr/bin/env bash
# Writes a table record, which opens a table and names its columns. Sourced,
# not executed: defines write_log_table.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

# Column names are plain words, so the caller names them alone and each takes
# the plain role here. The record still holds a pair per column, as every
# other record does.
#   write_log_table <column name...>
write_log_table() {

    local column_name
    local column_pairs=()

    for column_name in "$@"; do
        column_pairs+=("${LOG_ROLE_PLAIN}" "${column_name}")
    done

    write_log_record "${LOG_RECORD_KIND_TABLE}" "${column_pairs[@]}"
}
