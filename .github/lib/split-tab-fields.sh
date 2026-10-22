#!/usr/bin/env bash
# Splits a tab-separated line into its fields, keeping empty ones. Sourced,
# not executed: defines split_tab_fields.
#
# read -a would merge adjacent tabs, since a tab is IFS whitespace, and an
# empty field would shift every field after it one place left.

# Leaves the line's fields in the global array split_fields. Assigned rather
# than printed, so a long input costs no subshell per line.
#   split_tab_fields <line>
split_tab_fields() {

    local -r field_separator=$'\t'
    local rest="$1${field_separator}"

    split_fields=()

    while [[ -n "${rest}" ]]; do

        split_fields+=("${rest%%"${field_separator}"*}")
        rest="${rest#*"${field_separator}"}"
    done
}
