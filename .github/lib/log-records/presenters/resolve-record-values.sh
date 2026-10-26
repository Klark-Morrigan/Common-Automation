#!/usr/bin/env bash
# Resolves a record's values into what each shows. Sourced, not executed:
# defines resolve_record_values.
#
# Every printer and the table measure walk a record's role and text pairs the
# same way, so the walk is done once here and each reads the arrays it leaves.

# shellcheck source=SCRIPTDIR/../../split-fields.sh
source "${BASH_SOURCE[0]%/*}/../../split-fields.sh"

# shellcheck source=SCRIPTDIR/resolve-display-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-display-text.sh"

# Leaves the record's values in order in two arrays of one length:
# record_roles, each value's role, and record_display_texts, the text each
# shows. A last role with no text shows as nothing.
#   resolve_record_values <record line>
# shellcheck disable=SC2034 # the two arrays are the result, read by the caller
resolve_record_values() {

    local index

    record_roles=()
    record_display_texts=()

    split_line_fields "${LOG_RECORD_SEPARATOR}" "$1"

    for (( index = LOG_RECORD_FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do

        resolve_display_text "${split_fields[index]}" "${split_fields[index + 1]:-}"
        record_roles+=("${split_fields[index]}")
        record_display_texts+=("${display_text}")
    done
}
