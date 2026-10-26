#!/usr/bin/env bash
# Shapes a stage's log for the GitHub Actions step log.
#
# Usage: <stage> 2>&1 >/dev/null | present-log-for-actions.sh
#
# Reads the stage's stderr on stdin and writes the shaped log to stdout,
# shaped as present-log-for-terminal.sh shapes it, with two differences:
#
# - Colour is on. The Actions log renders ANSI colour, but its stream is never
#   a terminal, so the terminal presenter's gate would turn it off. NO_COLOR
#   still turns it off.
# - An error or notice record prints as the ::error:: or ::notice:: workflow
#   command it stands for, plain, so the run's annotations show it.
#
# The two presenters share every function in this folder and differ only in
# their loops.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The gate colors.sh reads on every call, so colour is on whatever stdout is.
# shellcheck disable=SC2034 # read by colors.sh
FORCE_COLOR=1

# shellcheck source=SCRIPTDIR/../../colors.sh
source "${script_dir}/../../colors.sh"

# shellcheck source=SCRIPTDIR/hold-table-record.sh
source "${script_dir}/hold-table-record.sh"

# shellcheck source=SCRIPTDIR/print-annotation-record.sh
source "${script_dir}/print-annotation-record.sh"

# shellcheck source=SCRIPTDIR/print-message-record.sh
source "${script_dir}/print-message-record.sh"

# The `|| [[ -n ... ]]` keeps a last line that has no newline.
while IFS= read -r line || [[ -n "${line}" ]]; do

    if hold_table_record "${line}"; then

        continue
    fi

    case "${record_kind}" in

        "${LOG_RECORD_KIND_MESSAGE}")
            print_message_record "${line}"
            ;;

        "${LOG_RECORD_KIND_ERROR}")
            print_annotation_record error "${line}"
            ;;

        "${LOG_RECORD_KIND_NOTICE}")
            print_annotation_record notice "${line}"
            ;;

        # Not a record, an unknown kind, or a row, total or end with no table
        # open. A workflow command a tool wrote itself still reaches the runner.
        *)
            printf '%s\n' "${line}"
            ;;
    esac
done

print_held_table
