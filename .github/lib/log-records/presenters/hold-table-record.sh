#!/usr/bin/env bash
# Holds a table's records until the table ends, then prints it. Sourced, not
# executed: defines hold_table_record and the held_table_lines it holds.
#
# A table is held because no column can be padded before every cell is known.
# Every presenter shapes tables alike, so each hands its lines here first and
# routes only what this does not take.

# shellcheck source=SCRIPTDIR/../resolve-record-kind.sh
source "${BASH_SOURCE[0]%/*}/../resolve-record-kind.sh"

# shellcheck source=SCRIPTDIR/print-held-table.sh
source "${BASH_SOURCE[0]%/*}/print-held-table.sh"

# The open table's record, then its rows and totals as they arrived. Empty
# while no table is open.
held_table_lines=()

# Takes a table, row, total or end record into the held table, printing the
# table once it ends. A table opened before the last one ended prints the last
# one first, so neither is lost.
# Returns 1, taking nothing, for any other line, and for a row, total or end
# with no table open: the caller prints those itself. Leaves the line's kind
# in record_kind either way, so the caller routes the line without reading it
# again.
#   hold_table_record <line>
hold_table_record() {

    resolve_record_kind "$1"

    case "${record_kind}" in

        "${LOG_RECORD_KIND_TABLE}")
            print_held_table
            held_table_lines=("$1")
            ;;

        "${LOG_RECORD_KIND_ROW}" | "${LOG_RECORD_KIND_TOTAL}")
            (( ${#held_table_lines[@]} > 0 )) || return 1
            held_table_lines+=("$1")
            ;;

        "${LOG_RECORD_KIND_END}")
            (( ${#held_table_lines[@]} > 0 )) || return 1
            print_held_table
            ;;

        *)
            return 1
            ;;
    esac
}
