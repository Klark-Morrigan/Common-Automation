#!/usr/bin/env bats
# Unit tests for hold-table-record.sh.
# Run with: bats .github/lib/log-records/presenters/hold-table-record.bats
#
# Each case calls hold_table_record in the suite's own shell, not through run,
# since the held table is state the next call reads.

# shellcheck source=SCRIPTDIR/hold-table-record.sh
source "${BATS_TEST_DIRNAME}/hold-table-record.sh"

setup() {

    unset NO_COLOR FORCE_COLOR

    held_table_lines=()
    printed_file="${BATS_TEST_TMPDIR}/printed"
}

# Hands each line to hold_table_record, printing to the printed file, and
# fails as soon as one is not taken.
#   hold_records <line...>
hold_records() {

    local line

    for line in "$@"; do
        hold_table_record "${line}" >> "${printed_file}" || return 1
    done
}

# Fails, naming the line, when hold_table_record takes it. A bare `! command`
# would never fail a bats case.
#   assert_line_not_taken <line>
assert_line_not_taken() {

    if hold_table_record "$1" >> "${printed_file}"; then

        echo "hold_table_record took: $1" >&2

        return 1
    fi
}

@test "holds a table's records, printing nothing, until its end record" {

    hold_records "$(printf '#log\ttable\t\tAsset')" "$(printf '#log\trow\tid\tKMU.zip')"

    [ ! -s "${printed_file}" ]
    [ "${#held_table_lines[@]}" -eq 2 ]
}

@test "prints the table at its end record and holds nothing after" {

    hold_records "$(printf '#log\ttable\t\tAsset')" "$(printf '#log\trow\tid\tKMU.zip')" "$(printf '#log\tend')"

    [ "$(cat "${printed_file}")" = "Asset
KMU.zip" ]
    [ "${#held_table_lines[@]}" -eq 0 ]
}

@test "prints the open table when the next one opens, and holds the next" {

    hold_records "$(printf '#log\ttable\t\tAsset')" "$(printf '#log\trow\tid\tKMU.zip')" \
        "$(printf '#log\ttable\t\tRelease')"

    [ "$(cat "${printed_file}")" = "Asset
KMU.zip" ]
    [ "${held_table_lines[*]}" = "$(printf '#log\ttable\t\tRelease')" ]
}

@test "takes no row, total or end with no table open" {

    local line

    for line in "$(printf '#log\trow\tid\tKMU.zip')" "$(printf '#log\ttotal\tcount\t1')" "$(printf '#log\tend')"; do
        assert_line_not_taken "${line}"
    done

    [ "${#held_table_lines[@]}" -eq 0 ]
    [ ! -s "${printed_file}" ]
}

@test "takes no message or plain line, while a table is held either" {

    hold_records "$(printf '#log\ttable\t\tAsset')"

    assert_line_not_taken "$(printf '#log\tmessage\t\tStill reading.')"
    assert_line_not_taken "retry: attempt 1 of 3 failed"

    [ "${#held_table_lines[@]}" -eq 1 ]
}

@test "leaves the kind of a line it does not take in record_kind" {

    assert_line_not_taken "$(printf '#log\terror\t\tfailed.')"

    [ "${record_kind}" = "error" ]
}
