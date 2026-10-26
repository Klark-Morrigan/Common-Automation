#!/usr/bin/env bash
# Resolves the one line of text a record's values make, uncoloured. Sourced,
# not executed: defines resolve_record_text.
#
# For a line shown in one colour or in none, where the values need not be
# printed apart: an error in red, or an annotation.

# shellcheck source=SCRIPTDIR/resolve-record-values.sh
source "${BASH_SOURCE[0]%/*}/resolve-record-values.sh"

# Leaves in record_text the record's display texts in order, joined with
# nothing between.
#   resolve_record_text <record line>
# shellcheck disable=SC2034 # record_text is the result, read by the caller
resolve_record_text() {

    local display_text_value

    record_text=""

    resolve_record_values "$1"

    for display_text_value in "${record_display_texts[@]}"; do
        record_text+="${display_text_value}"
    done
}
