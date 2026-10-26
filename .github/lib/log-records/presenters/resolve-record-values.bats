#!/usr/bin/env bats
# Unit tests for resolve-record-values.sh.
# Run with: bats .github/lib/log-records/presenters/resolve-record-values.bats

# shellcheck source=SCRIPTDIR/resolve-record-values.sh
source "${BATS_TEST_DIRNAME}/resolve-record-values.sh"

@test "leaves each value's role and display text, in order" {

    resolve_record_values "$(printf '#log\trow\tid\tKMU.zip\tlocale\tzh-hans\t\t')"

    [ "${#record_roles[@]}" -eq 3 ]
    [ "${record_roles[0]}" = "id" ]
    [ "${record_roles[1]}" = "locale" ]
    [ -z "${record_roles[2]}" ]
    [ "${record_display_texts[0]}" = "KMU.zip" ]
    [ "${record_display_texts[1]}" = "ZH-HANS" ]
    [ -z "${record_display_texts[2]}" ]
}

@test "resolves a last role that has no text to an empty text" {

    resolve_record_values "$(printf '#log\tmessage\t\tRead \tid')"

    [ "${record_roles[*]}" = " id" ]
    [ "${#record_display_texts[@]}" -eq 2 ]
    [ -z "${record_display_texts[1]}" ]
}

@test "leaves both arrays empty for a record with no pairs" {

    record_roles=(left over)
    record_display_texts=(left over)

    resolve_record_values "$(printf '#log\tend')"

    [ "${#record_roles[@]}" -eq 0 ]
    [ "${#record_display_texts[@]}" -eq 0 ]
}
