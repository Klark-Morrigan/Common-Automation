#!/usr/bin/env bash
# Prints a message record as one line. Sourced, not executed: defines
# print_message_record.

# shellcheck source=SCRIPTDIR/print-display-text.sh
source "${BASH_SOURCE[0]%/*}/print-display-text.sh"

# shellcheck source=SCRIPTDIR/resolve-record-values.sh
source "${BASH_SOURCE[0]%/*}/resolve-record-values.sh"

# Prints the record's values in order, each as its role shows it, then a
# newline.
#   print_message_record <record line>
print_message_record() {

    local index

    resolve_record_values "$1"

    for (( index = 0; index < ${#record_roles[@]}; index++ )); do
        print_display_text "${record_roles[index]}" "${record_display_texts[index]}"
    done

    printf '\n'
}
