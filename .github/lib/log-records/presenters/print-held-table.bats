#!/usr/bin/env bats
# Unit tests for print-held-table.sh.
# Run with: bats .github/lib/log-records/presenters/print-held-table.bats
#
# Each case calls print_held_table in the suite's own shell, not through run,
# since letting the table go is state the case reads back.

# shellcheck source=SCRIPTDIR/print-held-table.sh
source "${BATS_TEST_DIRNAME}/print-held-table.sh"

setup() {

    unset NO_COLOR FORCE_COLOR

    printed_file="${BATS_TEST_TMPDIR}/printed"
}

@test "prints the held table and holds nothing after" {

    held_table_lines=("$(printf '#log\ttable\t\tAsset')" "$(printf '#log\trow\tid\tKMU.zip')")

    print_held_table > "${printed_file}"

    [ "$(cat "${printed_file}")" = "Asset
KMU.zip" ]
    [ "${#held_table_lines[@]}" -eq 0 ]
}

@test "prints nothing while no table is held" {

    held_table_lines=()

    print_held_table > "${printed_file}"

    [ ! -s "${printed_file}" ]
}
