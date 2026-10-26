#!/usr/bin/env bash
# Prints the table hold_table_record holds, and lets it go. Sourced, not
# executed: defines print_held_table.
#
# Reads and clears held_table_lines, which hold-table-record.sh, beside this
# file, declares and fills.

# shellcheck source=SCRIPTDIR/print-table.sh
source "${BASH_SOURCE[0]%/*}/print-table.sh"

# Prints nothing while no table is held, so a presenter can flush at the end
# of its input whatever it holds.
#   print_held_table
print_held_table() {

    print_table "${held_table_lines[@]}"
    held_table_lines=()
}
