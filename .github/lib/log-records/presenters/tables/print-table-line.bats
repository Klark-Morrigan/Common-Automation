#!/usr/bin/env bats
# Unit tests for print-table-line.sh.
# Run with: bats .github/lib/log-records/presenters/tables/print-table-line.bats
#
# Each case sets the layout measure_table_columns would leave, so the line is
# printed against a known layout.

# shellcheck source=SCRIPTDIR/print-table-line.sh
source "${BATS_TEST_DIRNAME}/print-table-line.sh"

setup() {

    unset NO_COLOR FORCE_COLOR

    column_widths=(7 9 4)
    is_column_right_aligned=(false true false)
}

@test "pads a left-aligned cell after it and a right-aligned cell before it" {

    run print_table_line "$(printf '#log\trow\tid\tKMU\tcount\t120\t\tok')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "KMU            120  ok" ]
}

@test "ends the line at its last text, with no padding after it" {

    # The trailing dot keeps the command substitution from dropping a space.
    local printed_line

    printed_line="$(print_table_line "$(printf '#log\trow\tid\tKMU\t\t\t\t')"; printf '.')"

    [ "${printed_line}" = $'KMU\n.' ]
}

@test "keeps the columns aligned when the cells are coloured" {

    FORCE_COLOR=1 run print_table_line "$(printf '#log\trow\tid\tKMU\tcount\t120\t\tok')"

    [ "${status}" -eq 0 ]
    [ "${output}" = $'\033[38;2;255;230;0mKMU\033[0m            \033[32m120\033[0m  ok' ]
}
