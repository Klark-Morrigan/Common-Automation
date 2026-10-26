#!/usr/bin/env bash
# Prints one line of a measured table. Sourced, not executed: defines
# print_table_line.

# shellcheck source=SCRIPTDIR/../print-display-text.sh
source "${BASH_SOURCE[0]%/*}/../print-display-text.sh"

# shellcheck source=SCRIPTDIR/../resolve-record-values.sh
source "${BASH_SOURCE[0]%/*}/../resolve-record-values.sh"

# shellcheck source=SCRIPTDIR/table-layout-format.sh
source "${BASH_SOURCE[0]%/*}/table-layout-format.sh"

# Prints the record's cells, each padded to its column, then a newline. Reads
# the layout measure_table_columns left in column_widths and
# is_column_right_aligned.
#
# Padding is counted on the plain text and written outside the colour, so an
# escape code never skews a column. Spaces are held back until text follows
# them, so no line ends in padding.
#   print_table_line <record line>
# shellcheck disable=SC2154 # the layout arrays are set by measure_table_columns
print_table_line() {

    local pending_spaces=0
    local padding
    local column

    resolve_record_values "$1"

    for (( column = 0; column < ${#record_roles[@]}; column++ )); do

        padding=$(( column_widths[column] - ${#record_display_texts[column]} ))

        if [[ "${is_column_right_aligned[column]}" == true ]]; then

            pending_spaces=$(( pending_spaces + padding ))
        fi

        if [[ -n "${record_display_texts[column]}" ]]; then

            printf '%*s' "${pending_spaces}" ""
            print_display_text "${record_roles[column]}" "${record_display_texts[column]}"
            pending_spaces=0
        fi

        if [[ "${is_column_right_aligned[column]}" != true ]]; then

            pending_spaces=$(( pending_spaces + padding ))
        fi

        pending_spaces=$(( pending_spaces + ${#TABLE_COLUMN_GAP} ))
    done

    printf '\n'
}
