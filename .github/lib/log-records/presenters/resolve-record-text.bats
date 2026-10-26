#!/usr/bin/env bats
# Unit tests for resolve-record-text.sh.
# Run with: bats .github/lib/log-records/presenters/resolve-record-text.bats

# shellcheck source=SCRIPTDIR/resolve-record-text.sh
source "${BATS_TEST_DIRNAME}/resolve-record-text.sh"

@test "joins the values in order, each as its role shows it" {

    resolve_record_text "$(printf '#log\terror\t\tcould not read \tid\tKMU\t\t under \tlocale\tzh-hans')"

    [ "${record_text}" = "could not read KMU under ZH-HANS" ]
}

@test "resolves a last role that has no text to nothing" {

    resolve_record_text "$(printf '#log\tnotice\t\tpublished \tid')"

    [ "${record_text}" = "published " ]
}

@test "resolves a record with no pairs to nothing" {

    record_text="left over"

    resolve_record_text "$(printf '#log\tnotice')"

    [ -z "${record_text}" ]
}
