#!/usr/bin/env bash
# Writes a total record: a row of the open table that sums a column. A
# presenter shows the totals under a rule, after the other rows. Sourced, not
# executed: defines write_log_total.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

# One role and text pair per cell, in column order.
#   write_log_total <role> <cell text> [<role> <cell text>...]
write_log_total() {

    write_log_record "${LOG_RECORD_KIND_TOTAL}" "$@"
}
