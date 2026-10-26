#!/usr/bin/env bats
# Unit tests for print-table.sh.
# Run with: bats .github/lib/log-records/presenters/tables/print-table.bats

# shellcheck source=SCRIPTDIR/print-table.sh
source "${BATS_TEST_DIRNAME}/print-table.sh"

setup() {

    unset NO_COLOR FORCE_COLOR
}

@test "prints the header, the rows, then the totals under a rule as wide as the table" {

    run print_table \
        "$(printf '#log\ttable\t\tAsset\t\tDownloads')" \
        "$(printf '#log\ttotal\t\t\tcount\t127')" \
        "$(printf '#log\trow\tid\tKMU-en.zip\tcount\t120')" \
        "$(printf '#log\trow\tid\tKMU-zh.zip\tcount\t7')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Asset       Downloads
KMU-en.zip        120
KMU-zh.zip          7
---------------------
                  127" ]
}

@test "prints no rule for a table with no totals" {

    run print_table \
        "$(printf '#log\ttable\t\tAsset')" \
        "$(printf '#log\trow\tid\tKMU.zip')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Asset
KMU.zip" ]
}

@test "right-aligns a header narrower than the numbers under it" {

    run print_table \
        "$(printf '#log\ttable\t\tN')" \
        "$(printf '#log\trow\tcount\t12345')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "    N
12345" ]
}

@test "prints nothing when given nothing" {

    run print_table

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
