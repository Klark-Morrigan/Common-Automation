#!/usr/bin/env bash
# Prints a message record as one line. Sourced, not executed: defines
# print_message_record.

# shellcheck source=SCRIPTDIR/../../split-fields.sh
source "${BASH_SOURCE[0]%/*}/../../split-fields.sh"

# shellcheck source=SCRIPTDIR/print-display-text.sh
source "${BASH_SOURCE[0]%/*}/print-display-text.sh"

# shellcheck source=SCRIPTDIR/resolve-display-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-display-text.sh"

# Prints the record's values in order, each as its role shows it, then a
# newline.
#   print_message_record <record line>
print_message_record() {

    local index

    split_line_fields "${LOG_RECORD_SEPARATOR}" "$1"

    for (( index = LOG_RECORD_FIRST_PAIR_INDEX; index < ${#split_fields[@]}; index += 2 )); do

        resolve_display_text "${split_fields[index]}" "${split_fields[index + 1]:-}"
        print_display_text "${split_fields[index]}" "${display_text}"
    done

    printf '\n'
}
