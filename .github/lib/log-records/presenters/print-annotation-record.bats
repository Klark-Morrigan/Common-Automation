#!/usr/bin/env bats
# Unit tests for print-annotation-record.sh.
# Run with: bats .github/lib/log-records/presenters/print-annotation-record.bats

# shellcheck source=SCRIPTDIR/print-annotation-record.sh
source "${BATS_TEST_DIRNAME}/print-annotation-record.sh"

setup() {

    unset NO_COLOR FORCE_COLOR
}

@test "prints an error record as an error command, its values joined" {

    run print_annotation_record "$(printf '#log\terror\t\texample-stage: could not read \tid\tKMU')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "::error::example-stage: could not read KMU" ]
}

@test "prints a notice record as a notice command, plain under FORCE_COLOR" {

    FORCE_COLOR=1 run print_annotation_record "$(printf '#log\tnotice\t\tpublished \tid\tbadges')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "::notice::published badges" ]
}

@test "prints nothing for a record of another kind" {

    run print_annotation_record "$(printf '#log\tmessage\t\tRead.')"

    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
}
