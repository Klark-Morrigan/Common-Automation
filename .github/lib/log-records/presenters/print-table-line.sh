#!/usr/bin/env bash
# Prints one line of a measured table. Sourced, not executed: defines
# print_table_line.

# shellcheck source=SCRIPTDIR/../../split-fields.sh
source "${BASH_SOURCE[0]%/*}/../../split-fields.sh"

# shellcheck source=SCRIPTDIR/print-display-text.sh
source "${BASH_SOURCE[0]%/*}/print-display-text.sh"

# shellcheck source=SCRIPTDIR/resolve-display-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-display-text.sh"

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

    local column=0
    local pending_spaces=0
    local padding
    local index

    split_line_fields "${LOG_RECORD_SEPARATOR}" "$1"

    for (( index = LOG_RECORD_FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do

        resolve_display_text "${split_fields[index]}" "${split_fields[index + 1]:-}"
        padding=$(( column_widths[column] - ${#display_text} ))

        if [[ "${is_column_right_aligned[column]}" == true ]]; then

            pending_spaces=$(( pending_spaces + padding ))
        fi

        if [[ -n "${display_text}" ]]; then

            printf '%*s' "${pending_spaces}" ""
            print_display_text "${split_fields[index]}" "${display_text}"
            pending_spaces=0
        fi

        if [[ "${is_column_right_aligned[column]}" != true ]]; then

            pending_spaces=$(( pending_spaces + padding ))
        fi

        pending_spaces=$(( pending_spaces + ${#TABLE_COLUMN_GAP} ))
        column=$(( column + 1 ))
    done

    printf '\n'
}
