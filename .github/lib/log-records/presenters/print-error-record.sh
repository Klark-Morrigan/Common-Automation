#!/usr/bin/env bash
# Prints an error record as one red line, for a person at a terminal. Sourced,
# not executed: defines print_error_record.
#
# The whole line is red, whatever its values' roles, so a failure stands out
# from the log around it. Colour goes through colors.sh, gated on the stdout
# of the script that sourced it.

# shellcheck source=SCRIPTDIR/../../colors.sh
source "${BASH_SOURCE[0]%/*}/../../colors.sh"

# shellcheck source=SCRIPTDIR/resolve-record-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-record-text.sh"

# Prints the record's text in red, then a newline.
#   print_error_record <record line>
print_error_record() {

    resolve_record_text "$1"
    colorize_fd 1 red "${record_text}"
    printf '\n'
}
