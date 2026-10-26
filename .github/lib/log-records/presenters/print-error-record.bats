#!/usr/bin/env bats
# Unit tests for print-error-record.sh.
# Run with: bats .github/lib/log-records/presenters/print-error-record.bats

# shellcheck source=SCRIPTDIR/print-error-record.sh
source "${BATS_TEST_DIRNAME}/print-error-record.sh"

setup() {

    unset NO_COLOR FORCE_COLOR
}

@test "prints the whole line in red under FORCE_COLOR, whatever its roles" {

    FORCE_COLOR=1 run print_error_record "$(printf '#log\terror\t\texample-stage: could not read \tid\tKMU')"

    [ "${status}" -eq 0 ]
    [ "${output}" = $'\033[31mexample-stage: could not read KMU\033[0m' ]
}

@test "prints plain when stdout is not a terminal" {

    run print_error_record "$(printf '#log\terror\t\texample-stage: failed.')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "example-stage: failed." ]
}
