#!/usr/bin/env bats
# Unit tests for write-log-record.sh.
# Run with: bats .github/lib/log-records/write-log-record.bats
#
# Every writer calls write_log_record, so the flattening every writer relies
# on is held here once.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BATS_TEST_DIRNAME}/write-log-record.sh"

@test "writes the marker, the kind and each value, tab-separated, to stderr alone" {

    run --separate-stderr write_log_record row id "KMU.zip" count 12

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\trow\tid\tKMU.zip\tcount\t12')" ]
}

@test "keeps an empty role and an empty text as fields of their own" {

    run --separate-stderr write_log_record row "" "" count 12

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$(printf '#log\trow\t\t\tcount\t12')" ]
}

@test "writes the marker and the kind alone for a record with no values" {

    run --separate-stderr write_log_record end

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$(printf '#log\tend')" ]
}

@test "flattens a tab inside a text to a space" {

    run --separate-stderr write_log_record message "" "$(printf 'a\tb')"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$(printf '#log\tmessage\t\ta b')" ]
}

@test "flattens a newline and a carriage return inside a text to spaces" {

    run --separate-stderr write_log_record message "" "$(printf 'a\nb\rc')"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$(printf '#log\tmessage\t\ta b c')" ]
}

@test "fails, writing no record, when the values do not pair up" {

    run --separate-stderr write_log_record row id "KMU.zip" count

    [ "${status}" -eq 1 ]
    [ "${stderr}" = "write_log_record: a row record takes role and text pairs; got 3 values." ]
}
