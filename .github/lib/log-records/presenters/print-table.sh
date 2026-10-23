#!/usr/bin/env bash
# Prints a held table, padded, with its totals under a rule. Sourced, not
# executed: defines print_table.

# shellcheck source=SCRIPTDIR/../resolve-record-kind.sh
source "${BASH_SOURCE[0]%/*}/../resolve-record-kind.sh"

# shellcheck source=SCRIPTDIR/measure-table-columns.sh
source "${BASH_SOURCE[0]%/*}/measure-table-columns.sh"

# shellcheck source=SCRIPTDIR/print-table-line.sh
source "${BASH_SOURCE[0]%/*}/print-table-line.sh"

# shellcheck source=SCRIPTDIR/table-layout-format.sh
source "${BASH_SOURCE[0]%/*}/table-layout-format.sh"

# Prints the header, then the rows, then a rule as wide as the table and the
# totals under it. Totals print last whenever they arrived, and with no total
# there is no rule. Prints nothing when given nothing, so a caller can flush
# whatever it holds.
#   print_table [<table record> [<row or total record>...]]
print_table() {

    local -r rule_character="-"
    local row_lines=()
    local total_lines=()
    local line
    local width
    local table_width=0
    local rule

    if (( $# == 0 )); then

        return 0
    fi

    for line in "${@:2}"; do

        resolve_record_kind "${line}"

        if [[ "${record_kind}" == "${LOG_RECORD_KIND_TOTAL}" ]]; then

            total_lines+=("${line}")
        else
            row_lines+=("${line}")
        fi
    done

    measure_table_columns "$@"
    print_table_line "$1"

    for line in "${row_lines[@]}"; do
        print_table_line "${line}"
    done

    if (( ${#total_lines[@]} == 0 )); then

        return 0
    fi

    for width in "${column_widths[@]}"; do
        table_width=$(( table_width + width + ${#TABLE_COLUMN_GAP} ))
    done

    printf -v rule '%*s' "$(( table_width - ${#TABLE_COLUMN_GAP} ))" ""
    printf '%s\n' "${rule// /${rule_character}}"

    for line in "${total_lines[@]}"; do
        print_table_line "${line}"
    done
}
