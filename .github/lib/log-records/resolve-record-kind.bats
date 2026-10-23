#!/usr/bin/env bats
# Unit tests for resolve-record-kind.sh.
# Run with: bats .github/lib/log-records/resolve-record-kind.bats

# shellcheck source=SCRIPTDIR/resolve-record-kind.sh
source "${BATS_TEST_DIRNAME}/resolve-record-kind.sh"

@test "reads the kind of a record with pairs" {

    resolve_record_kind "$(printf '#log\trow\tid\tKMU.zip')"

    [ "${record_kind}" = "row" ]
}

@test "reads the kind of a record with no pairs" {

    resolve_record_kind "$(printf '#log\tend')"

    [ "${record_kind}" = "end" ]
}

@test "leaves the kind empty for a line that is not a record" {

    resolve_record_kind "retry: attempt 1 of 3 failed"

    [ -z "${record_kind}" ]
}

@test "leaves the kind empty for the marker with no separator after it" {

    resolve_record_kind "#logged elsewhere"

    [ -z "${record_kind}" ]
}
