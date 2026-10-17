#!/usr/bin/env bash
# Appends a Markdown table to the job summary, the page a run shows in the
# Actions tab.
#
# Usage: write-step-summary-table.sh <heading> <column name...> < lines
#
# Reads tab-separated lines on stdin, one table row each, with as many fields
# as columns are named. A field may be empty. Writes the heading, the header
# row and one row per line to the file GITHUB_STEP_SUMMARY names, after
# whatever the file already holds. Empty input writes the heading and the
# header row alone, so the page still shows the table was read and held
# nothing.
#
# Knows nothing of what the lines mean, so any stage can show its data this
# way under columns of its own.
#
# Logs the heading and its row count to stderr.
#
# Exits non-zero, writing nothing, when GITHUB_STEP_SUMMARY is unset or a line
# holds a different number of fields than columns are named.

set -euo pipefail

readonly FIELD_SEPARATOR=$'\t'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=SCRIPTDIR/workflow-commands.sh
source "${script_dir}/workflow-commands.sh"

summary_file="${GITHUB_STEP_SUMMARY:-}"
heading="${1:-}"

require_value GITHUB_STEP_SUMMARY "${summary_file}"
require_value "heading" "${heading}"

shift

if (( $# == 0 )); then

    exit_with_error "at least one column name is required."
fi

column_names=("$@")

# Splits one line into the global array line_fields, keeping empty fields.
# read -a would merge adjacent tabs, since a tab is IFS whitespace, and an
# empty field would shift every field after it one column left.
#   split_line_fields <line>
split_line_fields() {

    local rest="$1${FIELD_SEPARATOR}"

    line_fields=()

    while [[ -n "${rest}" ]]; do

        line_fields+=("${rest%%"${FIELD_SEPARATOR}"*}")
        rest="${rest#*"${FIELD_SEPARATOR}"}"
    done
}

# Appends the given cells to the global table as one row. Built in place
# rather than printed, so a long input costs no subshell per row.
# A | would end its cell early, so it is escaped; it renders as itself.
#   append_table_row <cell...>
append_table_row() {

    local cell

    table+="|"

    for cell in "$@"; do
        table+=" ${cell//|/\\|} |"
    done

    table+=$'\n'
}

delimiter_cells=()

for _ in "${column_names[@]}"; do
    delimiter_cells+=("---")
done

table="## ${heading}"$'\n\n'

append_table_row "${column_names[@]}"
append_table_row "${delimiter_cells[@]}"

row_count=0

# The table is built whole before anything is written, so a bad line leaves
# the summary as it was. The `|| [[ -n ... ]]` keeps a last line that has no
# newline.
while IFS= read -r line || [[ -n "${line}" ]]; do

    split_line_fields "${line}"

    if (( ${#line_fields[@]} != ${#column_names[@]} )); then

        # Joined with commas: the tabs of the raw line do not show in an
        # annotation.
        printf -v joined_fields '%s, ' "${line_fields[@]}"
        joined_fields="${joined_fields%, }"

        exit_with_error "line '${joined_fields}' holds ${#line_fields[@]} fields;" \
            "table '${heading}' has ${#column_names[@]} columns."
    fi

    append_table_row "${line_fields[@]}"
    row_count=$(( row_count + 1 ))
done

# The blank line ends the table, so whatever is appended next cannot be read
# as one of its rows.
printf '%s\n' "${table}" >> "${summary_file}"

echo "Wrote table '${heading}' to the job summary: ${row_count} rows." >&2
