#!/usr/bin/env bats
# Unit tests for measure-table-columns.sh.
# Run with: bats .github/lib/log-records/presenters/tables/measure-table-columns.bats

# shellcheck source=SCRIPTDIR/measure-table-columns.sh
source "${BATS_TEST_DIRNAME}/measure-table-columns.sh"

@test "widens each column to its widest display text, the header included" {

    measure_table_columns \
        "$(printf '#log\ttable\t\tAsset\t\tLocale')" \
        "$(printf '#log\trow\tid\tKMU.zip\tlocale\tzh-hans')"

    [ "${column_widths[*]}" = "7 7" ]
}

@test "right-aligns a column whose filled body cells are all integers" {

    measure_table_columns \
        "$(printf '#log\ttable\t\tRelease\t\tDownloads')" \
        "$(printf '#log\trow\t\t0.2.0\tcount\t120')" \
        "$(printf '#log\trow\t\t10\t\t')" \
        "$(printf '#log\ttotal\t\t\tcount\t120')"

    [ "${is_column_right_aligned[*]}" = "false true" ]
}

@test "lets no header decide a column's alignment" {

    measure_table_columns \
        "$(printf '#log\ttable\t\t2024')" \
        "$(printf '#log\trow\t\twords')"

    [ "${is_column_right_aligned[*]}" = "false" ]
}

@test "leaves a column with no filled body cell left-aligned" {

    measure_table_columns \
        "$(printf '#log\ttable\t\tNote')" \
        "$(printf '#log\trow\t\t')"

    [ "${is_column_right_aligned[*]}" = "false" ]
}
