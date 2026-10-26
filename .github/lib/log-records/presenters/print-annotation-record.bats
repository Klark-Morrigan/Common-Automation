#!/usr/bin/env bats
# Unit tests for print-annotation-record.sh.
# Run with: bats .github/lib/log-records/presenters/print-annotation-record.bats

# shellcheck source=SCRIPTDIR/print-annotation-record.sh
source "${BATS_TEST_DIRNAME}/print-annotation-record.sh"

setup() {

    unset NO_COLOR FORCE_COLOR
}

@test "prints the record as the named workflow command, its values joined" {

    run print_annotation_record error "$(printf '#log\terror\t\texample-stage: could not read \tid\tKMU')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "::error::example-stage: could not read KMU" ]
}

@test "prints plain under FORCE_COLOR" {

    FORCE_COLOR=1 run print_annotation_record notice "$(printf '#log\tnotice\t\tpublished \tid\tbadges')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "::notice::published badges" ]
}
