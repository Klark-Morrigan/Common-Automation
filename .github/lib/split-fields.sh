#!/usr/bin/env bash
# Splits a line into its fields at a separator, keeping empty ones. Sourced,
# not executed: defines split_line_fields.
#
# read -a would merge adjacent tabs, since a tab is IFS whitespace, and an
# empty field would shift every field after it one place left. The separator
# is passed in, so each line format states its own rather than this file
# assuming one.

# Leaves the line's fields in the global array split_fields. Assigned rather
# than printed, so a long input costs no subshell per line.
#   split_line_fields <separator> <line>
split_line_fields() {

    local separator="$1"
    local rest="$2${separator}"

    split_fields=()

    while [[ -n "${rest}" ]]; do

        split_fields+=("${rest%%"${separator}"*}")
        rest="${rest#*"${separator}"}"
    done
}
