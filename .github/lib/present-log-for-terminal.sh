#!/usr/bin/env bash
# Shapes a stage's log for a person at a terminal.
#
# Usage: <stage> 2>&1 >/dev/null | present-log-for-terminal.sh
#
# Reads the stage's stderr on stdin and writes the shaped log to stdout. A
# stage writes its log as plain records, through log-records/, so it never
# decides how its log looks; log-records/log-record-format.sh states the
# format.
#
# - A message record prints as one line, each value coloured by its role.
# - A table is held until its end record, since no column can be padded
#   before every cell is known. Then each column is padded to its widest cell
#   and each cell coloured. The totals print under a rule.
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

set -euo pipefail

readonly COLUMN_GAP="  "
readonly RULE_CHARACTER="-"

# A column whose filled cells all match this is a column of counts, and is
# right-aligned so the digits line up.
readonly INTEGER_REGEX='^[0-9]+$'

# A record's pairs start after its marker and kind.
readonly FIRST_PAIR_INDEX=2

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=SCRIPTDIR/colors.sh
source "${script_dir}/colors.sh"

# shellcheck source=SCRIPTDIR/log-records/log-record-format.sh
source "${script_dir}/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/split-tab-fields.sh
source "${script_dir}/split-tab-fields.sh"

is_table_open=false
held_header_line=""
held_row_lines=()
held_total_lines=()

# Leaves in display_text the text a value shows: a locale tag upper-cased,
# anything else as written.
#   resolve_display_text <role> <text>
resolve_display_text() {

    if [[ "$1" == "locale" ]]; then

        display_text="${2^^}"
    else
        display_text="$2"
    fi
}

# Leaves in role_color the colors.sh colour a role takes, or nothing for a
# role shown in the terminal's own text colour.
#   resolve_role_color <role>
resolve_role_color() {

    case "$1" in
        id)            role_color="yellow" ;;
        count|current) role_color="green"  ;;
        stale)         role_color="grey"   ;;
        invalid)       role_color="red"    ;;
        *)             role_color=""       ;;
    esac
}

# Prints a value as its role shows it, with no newline.
#   print_value <role> <text>
print_value() {

    resolve_display_text "$1" "$2"
    resolve_role_color "$1"

    if [[ -z "${role_color}" ]]; then

        printf '%s' "${display_text}"
        return 0
    fi

    colorize_fd 1 "${role_color}" "${display_text}"
}

# Prints a message record as one line, its values in order.
#   print_message <record line>
print_message() {

    local index

    split_tab_fields "$1"

    for (( index = FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do
        print_value "${split_fields[index]}" "${split_fields[index + 1]:-}"
    done

    printf '\n'
}

# Widens the held table's columns to fit one of its lines. A body line also
# decides which columns hold counts; the header never does, its names being
# words.
#   measure_table_line <record line> <is body line>
measure_table_line() {

    local is_body_line="$2"
    local column=0
    local index

    split_tab_fields "$1"

    for (( index = FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do

        resolve_display_text "${split_fields[index]}" "${split_fields[index + 1]:-}"

        if (( ${#display_text} > ${column_widths[column]:-0} )); then

            column_widths[column]=${#display_text}
        fi

        if [[ "${is_body_line}" == true && -n "${display_text}" ]]; then

            if [[ "${display_text}" =~ ${INTEGER_REGEX} ]]; then

                has_column_integer[column]=true
            else
                has_column_word[column]=true
            fi
        fi

        column=$(( column + 1 ))
    done
}

# Prints one line of the held table, each cell padded to its column. Padding
# is counted on the plain text and written outside the colour, so an escape
# code never skews a column. Spaces are held back until text follows them,
# so no line ends in padding.
#   print_table_line <record line>
print_table_line() {

    local column=0
    local pending_spaces=0
    local padding
    local is_right_aligned
    local index

    split_tab_fields "$1"

    for (( index = FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do

        resolve_display_text "${split_fields[index]}" "${split_fields[index + 1]:-}"
        padding=$(( column_widths[column] - ${#display_text} ))
        is_right_aligned=false

        if [[ "${has_column_integer[column]:-false}" == true && "${has_column_word[column]:-false}" != true ]]; then

            is_right_aligned=true
        fi

        if [[ "${is_right_aligned}" == true ]]; then

            pending_spaces=$(( pending_spaces + padding ))
        fi

        if [[ -n "${display_text}" ]]; then

            printf '%*s' "${pending_spaces}" ""
            print_value "${split_fields[index]}" "${split_fields[index + 1]:-}"
            pending_spaces=0
        fi

        if [[ "${is_right_aligned}" != true ]]; then

            pending_spaces=$(( pending_spaces + padding ))
        fi

        pending_spaces=$(( pending_spaces + ${#COLUMN_GAP} ))
        column=$(( column + 1 ))
    done

    printf '\n'
}

# Prints the held table, padded, its totals under a rule as wide as the
# table, then closes it.
#   print_held_table
print_held_table() {

    local line
    local table_width=0
    local width
    local rule

    column_widths=()
    has_column_integer=()
    has_column_word=()

    measure_table_line "${held_header_line}" false

    for line in "${held_row_lines[@]}" "${held_total_lines[@]}"; do
        measure_table_line "${line}" true
    done

    print_table_line "${held_header_line}"

    for line in "${held_row_lines[@]}"; do
        print_table_line "${line}"
    done

    if (( ${#held_total_lines[@]} > 0 )); then

        for width in "${column_widths[@]}"; do
            table_width=$(( table_width + width + ${#COLUMN_GAP} ))
        done

        table_width=$(( table_width - ${#COLUMN_GAP} ))

        printf -v rule '%*s' "${table_width}" ""
        printf '%s\n' "${rule// /${RULE_CHARACTER}}"

        for line in "${held_total_lines[@]}"; do
            print_table_line "${line}"
        done
    fi

    is_table_open=false
    held_header_line=""
    held_row_lines=()
    held_total_lines=()
}

# The `|| [[ -n ... ]]` keeps a last line that has no newline.
while IFS= read -r line || [[ -n "${line}" ]]; do

    if [[ "${line}" != "${LOG_RECORD_MARKER}${LOG_RECORD_SEPARATOR}"* ]]; then

        printf '%s\n' "${line}"
        continue
    fi

    split_tab_fields "${line}"

    case "${split_fields[1]}:${is_table_open}" in

        "${LOG_RECORD_KIND_MESSAGE}":*)
            print_message "${line}"
            ;;

        # A table opened before the last one ended closes the last one, so
        # neither is lost.
        "${LOG_RECORD_KIND_TABLE}":*)
            if [[ "${is_table_open}" == true ]]; then

                print_held_table
            fi

            is_table_open=true
            held_header_line="${line}"
            ;;

        "${LOG_RECORD_KIND_ROW}":true)
            held_row_lines+=("${line}")
            ;;

        "${LOG_RECORD_KIND_TOTAL}":true)
            held_total_lines+=("${line}")
            ;;

        "${LOG_RECORD_KIND_END}":true)
            print_held_table
            ;;

        # An unknown kind, or a row, total or end with no table open.
        *)
            printf '%s\n' "${line}"
            ;;
    esac
done

if [[ "${is_table_open}" == true ]]; then

    print_held_table
fi
