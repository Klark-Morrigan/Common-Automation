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
# A run's figures can only be traced on its page if the counts behind them are
# there, and a run that fails later still needs to show what it read. This
# script knows nothing of what the lines mean, so every source's lines go
# through it under columns of their own.
#
# Logs the heading and its row count to stderr.
#
# Exits non-zero, writing nothing, when GITHUB_STEP_SUMMARY is unset or a line
# holds a different number of fields than columns are named.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

readonly FIELD_SEPARATOR=$'\t'

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

# Prints the given cells as one table row, without its newline.
# A | would end its cell early, so it is escaped; it renders as itself.
#   build_table_row <cell...>
build_table_row() {

    local cell
    local row="|"

    for cell in "$@"; do

        cell="${cell//|/\\|}"
        row+=" ${cell} |"
    done

    printf '%s' "${row}"
}

delimiter_cells=()

for _ in "${column_names[@]}"; do
    delimiter_cells+=("---")
done

table="## ${heading}"$'\n\n'
table+="$(build_table_row "${column_names[@]}")"$'\n'
table+="$(build_table_row "${delimiter_cells[@]}")"$'\n'

row_count=0

# The table is built whole before anything is written, so a bad line leaves
# the summary as it was. The `|| [[ -n ... ]]` keeps a last line that has no
# newline.
while IFS= read -r line || [[ -n "${line}" ]]; do

    split_line_fields "${line}"

    if (( ${#line_fields[@]} != ${#column_names[@]} )); then

        exit_with_error "'${line}' holds ${#line_fields[@]} fields; table '${heading}' has ${#column_names[@]} columns."
    fi

    table+="$(build_table_row "${line_fields[@]}")"$'\n'
    row_count=$(( row_count + 1 ))
done

# The blank line ends the table, so whatever is appended next cannot be read
# as one of its rows.
printf '%s\n' "${table}" >> "${summary_file}"

echo "Wrote table '${heading}' to the job summary: ${row_count} rows." >&2
