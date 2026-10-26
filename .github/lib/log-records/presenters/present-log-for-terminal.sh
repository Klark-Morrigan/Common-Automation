#!/usr/bin/env bash
# Shapes a stage's log for a person at a terminal.
#
# Usage: <stage> 2>&1 >/dev/null | present-log-for-terminal.sh
#
# Reads the stage's stderr on stdin and writes the shaped log to stdout. A
# stage writes its log as plain records, through ../writers/, so it never
# decides how its log looks; ../log-record-format.sh states the format.
#
# - A message record prints as one line, each value coloured by its role.
# - A table is held until its end record, since no column can be padded
#   before every cell is known. Then each column is padded to its widest cell
#   and each cell coloured. The totals print under a rule.
# - An error record prints as one red line, and a notice record as a message.
#   Each names the script that wrote it, as its annotation would under GitHub
#   Actions.
# - Any other line passes through unchanged, an unknown record kind included.
#   So curl's errors, retry: lines and git's output still show, and each stage
#   can move onto records on its own.
#
# A line arriving while a table is held prints at once, ahead of the table,
# so a stage that stalls mid-table still shows what it is doing. A table
# still open when input ends prints then, so a stage that failed mid-table
# still shows its rows.
#
# Colour goes through colors.sh, gated on this script's stdout: on in a
# terminal, off when piped or captured, and NO_COLOR and FORCE_COLOR override
# it as colors.sh documents.
#
# present-log-for-actions.sh shapes the same records for the Actions log. The
# two share every function in this folder and differ only in this loop.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourced first, so the colour gate reads this script's stdout.
# shellcheck source=SCRIPTDIR/../../colors.sh
source "${script_dir}/../../colors.sh"

# shellcheck source=SCRIPTDIR/hold-table-record.sh
source "${script_dir}/hold-table-record.sh"

# shellcheck source=SCRIPTDIR/print-error-record.sh
source "${script_dir}/print-error-record.sh"

# shellcheck source=SCRIPTDIR/print-message-record.sh
source "${script_dir}/print-message-record.sh"

# The `|| [[ -n ... ]]` keeps a last line that has no newline.
while IFS= read -r line || [[ -n "${line}" ]]; do

    if hold_table_record "${line}"; then

        continue
    fi

    case "${record_kind}" in

        "${LOG_RECORD_KIND_MESSAGE}" | "${LOG_RECORD_KIND_NOTICE}")
            print_message_record "${line}"
            ;;

        "${LOG_RECORD_KIND_ERROR}")
            print_error_record "${line}"
            ;;

        # Not a record, an unknown kind, or a row, total or end with no table
        # open.
        *)
            printf '%s\n' "${line}"
            ;;
    esac
done

print_held_table
