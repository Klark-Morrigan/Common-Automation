#!/usr/bin/env bats
# Unit tests for _run-recorded-check.sh, the one check of a local CI run.
# Run with: bats scripts/_run-recorded-check.bats

setup() {

    # shellcheck source=SCRIPTDIR/../.github/lib/print-section-heading.sh
    source "${BATS_TEST_DIRNAME}/../.github/lib/print-section-heading.sh"

    # shellcheck source=SCRIPTDIR/_run-recorded-check.sh
    source "${BATS_TEST_DIRNAME}/_run-recorded-check.sh"
}

# Stands in for a check that takes <seconds> by moving bash's clock on, so
# the reported time does not depend on how fast the host runs.
#   take_seconds <seconds> <exit status>
take_seconds() {

    SECONDS=$(( SECONDS + $1 ))

    return "$2"
}

@test "heads the check, runs it and reports it passed with its time" {

    run run_recorded_check "yamllint" take_seconds 7 0

    [ "${status}" -eq 0 ]
    [ "${output}" = "=== yamllint ===
yamllint passed in 7s." ]
}

@test "reports a failed check with its time, and does not fail itself" {

    run run_recorded_check "yamllint" take_seconds 3 1

    [ "${status}" -eq 0 ]
    [ "${lines[1]}" = "yamllint FAILED in 3s." ]
}

@test "records each failed check by label, in the order they ran" {

    run_recorded_check "shellcheck domain (.)" false
    run_recorded_check "actionlint" true
    run_recorded_check "markdownlint" false

    [ "${#failed_checks[@]}" -eq 2 ]
    [ "${failed_checks[0]}" = "shellcheck domain (.)" ]
    [ "${failed_checks[1]}" = "markdownlint" ]
}

@test "records nothing when the check passes" {

    run_recorded_check "actionlint" true

    [ "${#failed_checks[@]}" -eq 0 ]
}

@test "hands the command its arguments unchanged" {

    run run_recorded_check "echo" printf '[%s]' "two words" "*"

    [ "${lines[1]}" = "[two words][*]echo passed in 0s." ]
}
