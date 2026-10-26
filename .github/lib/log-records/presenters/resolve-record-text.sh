#!/usr/bin/env bash
# Resolves the one line of text a record's values make, uncoloured. Sourced,
# not executed: defines resolve_record_text.
#
# A line shown in one colour, or none, has no use for its values apart: an
# error printed in red, an annotation, which the GitHub Actions annotations
# panel shows plain.

# shellcheck source=SCRIPTDIR/../../split-fields.sh
source "${BASH_SOURCE[0]%/*}/../../split-fields.sh"

# shellcheck source=SCRIPTDIR/resolve-display-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-display-text.sh"

# Leaves in record_text the record's values in order, each as its role shows
# it, joined with nothing between.
#   resolve_record_text <record line>
# shellcheck disable=SC2034 # record_text is the result, read by the caller
resolve_record_text() {

    local index

    record_text=""

    split_line_fields "${LOG_RECORD_SEPARATOR}" "$1"

    for (( index = LOG_RECORD_FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do

        resolve_display_text "${split_fields[index]}" "${split_fields[index + 1]:-}"
        record_text+="${display_text}"
    done
}
