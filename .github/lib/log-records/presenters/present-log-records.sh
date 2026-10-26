#!/usr/bin/env bash
# Routes a stage's log, line by line, to the printer each line needs. Sourced,
# not executed: defines present_log_records, the loop every presenter runs.
#
# - A message record prints as one line, each value as its role shows it.
# - A table is held until its end record, then printed padded, its totals
#   under a rule.
# - An error or notice record goes to the printer the presenter hands in,
#   since that is where presenters differ.
# - Any other line passes through unchanged, an unknown record kind included.
#   So curl's errors, retry: lines and git's output still show, and each stage
#   can move onto records on its own.
#
# A line arriving while a table is held prints at once, ahead of the table,
# so a stage that stalls mid-table still shows what it is doing. A table
# still open when input ends prints then, so a stage that failed mid-table
# still shows its rows.

# shellcheck source=SCRIPTDIR/print-message-record.sh
source "${BASH_SOURCE[0]%/*}/print-message-record.sh"

# shellcheck source=SCRIPTDIR/tables/hold-table-record.sh
source "${BASH_SOURCE[0]%/*}/tables/hold-table-record.sh"

# Reads the log on stdin and writes it shaped to stdout. Each printer is the
# name of a function taking the record line.
#   present_log_records <error record printer> <notice record printer>
present_log_records() {

    local error_record_printer="$1"
    local notice_record_printer="$2"
    local line

    # The `|| [[ -n ... ]]` keeps a last line that has no newline.
    while IFS= read -r line || [[ -n "${line}" ]]; do

        # shellcheck disable=SC2310 # its status says whether it took the line, not that it failed
        if hold_table_record "${line}"; then

            continue
        fi

        case "${record_kind}" in

            "${LOG_RECORD_KIND_MESSAGE}")
                print_message_record "${line}"
                ;;

            "${LOG_RECORD_KIND_ERROR}")
                "${error_record_printer}" "${line}"
                ;;

            "${LOG_RECORD_KIND_NOTICE}")
                "${notice_record_printer}" "${line}"
                ;;

            # Not a record, an unknown kind, or a row, total or end with no
            # table open.
            *)
                printf '%s\n' "${line}"
                ;;
        esac
    done

    print_held_table
}
