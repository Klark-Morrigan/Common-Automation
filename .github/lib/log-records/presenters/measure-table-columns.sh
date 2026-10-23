#!/usr/bin/env bash
# Measures a held table's columns before any of it prints. Sourced, not
# executed: defines measure_table_columns.

# shellcheck source=SCRIPTDIR/../../split-fields.sh
source "${BASH_SOURCE[0]%/*}/../../split-fields.sh"

# shellcheck source=SCRIPTDIR/resolve-display-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-display-text.sh"

# Leaves the table's layout in two arrays indexed by column:
# - column_widths, each column's widest display text;
# - is_column_right_aligned, true for a column whose filled body cells are all
#   integers, so its digits line up. The header never decides alignment, its
#   names being words.
# The table record comes first; rows and totals follow in any order.
#   measure_table_columns <table record> [<row or total record>...]
# shellcheck disable=SC2034 # the two arrays are the result, read by the caller
measure_table_columns() {

    local -r integer_regex='^[0-9]+$'
    local has_column_integer=()
    local has_column_word=()
    local is_body_line=false
    local line
    local column
    local index

    column_widths=()
    is_column_right_aligned=()

    for line in "$@"; do

        split_line_fields "${LOG_RECORD_SEPARATOR}" "${line}"
        column=0

        for (( index = LOG_RECORD_FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do

            resolve_display_text "${split_fields[index]}" "${split_fields[index + 1]:-}"

            if (( ${#display_text} > ${column_widths[column]:-0} )); then

                column_widths[column]=${#display_text}
            fi

            if [[ "${is_body_line}" == true && "${display_text}" =~ ${integer_regex} ]]; then

                has_column_integer[column]=true
            elif [[ "${is_body_line}" == true && -n "${display_text}" ]]; then

                has_column_word[column]=true
            fi

            column=$(( column + 1 ))
        done

        is_body_line=true
    done

    for (( column = 0; column < ${#column_widths[@]}; column++ )); do

        is_column_right_aligned[column]=false

        if [[ "${has_column_integer[column]:-false}" == true && "${has_column_word[column]:-false}" != true ]]; then

            is_column_right_aligned[column]=true
        fi
    done
}
