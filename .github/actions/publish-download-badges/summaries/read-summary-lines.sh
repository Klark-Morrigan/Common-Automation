#!/usr/bin/env bash
# Reads tab-separated summary lines into one array per field. Sourced, not
# executed: defines read_summary_lines.
#
# The release summary and a source's summary differ only in their fields, so
# both readers read through this one loop. Each reader keeps its own failure
# message and its own rule on empty input.

# Reads every line on stdin, checking it against <line regex>, and stores
# capture group N of line M at index M of the Nth named array. The caller
# empties the arrays first, where shellcheck can see them assigned. The last
# field is the download count, read as decimal: bash would take a leading zero
# for octal. A last line with no newline is still read.
#
# Returns 1 at the first line that does not match, leaving it in
# UNMATCHED_SUMMARY_LINE, so the caller names it in its own words.
#   read_summary_lines <line regex> <array name...> < lines
# shellcheck disable=SC2034 # UNMATCHED_SUMMARY_LINE is read by the caller
read_summary_lines() {

    local line_regex="$1"

    shift

    local array_names=("$@")
    local last_field_index=$(( ${#array_names[@]} - 1 ))
    local line_count=0
    local field_index field_value summary_line

    UNMATCHED_SUMMARY_LINE=""

    while IFS= read -r summary_line || [[ -n "${summary_line}" ]]; do

        if [[ ! "${summary_line}" =~ ${line_regex} ]]; then
            UNMATCHED_SUMMARY_LINE="${summary_line}"
            return 1
        fi

        for field_index in "${!array_names[@]}"; do

            field_value="${BASH_REMATCH[field_index + 1]}"

            if (( field_index == last_field_index )); then
                field_value="$(( 10#${field_value} ))"
            fi

            printf -v "${array_names[field_index]}[${line_count}]" '%s' "${field_value}"
        done

        line_count=$(( line_count + 1 ))
    done
}
