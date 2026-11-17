#!/usr/bin/env bats
# Unit tests for _report-check-summary.sh, the verdict ending a local CI run.
# Run with: bats scripts/_report-check-summary.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

setup() {

    # shellcheck source=SCRIPTDIR/_report-check-summary.sh
    source "${BATS_TEST_DIRNAME}/_report-check-summary.sh"
}

@test "says the scope passed when no check failed" {

    run report_check_summary "lint checks"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Lint checks passed." ]
}

@test "lists every failed check under the scope, one per line, and fails" {

    run report_check_summary "lint checks" "shellcheck domain (.)" "markdownlint"

    [ "${status}" -eq 1 ]
    [ "${output}" = "FAILED (lint checks):
  shellcheck domain (.)
  markdownlint" ]
}

@test "writes the failure list to stderr" {

    run --separate-stderr report_check_summary "lint checks" "markdownlint"

    [ "${output}" = "" ]
    [ "${stderr}" = "FAILED (lint checks):
  markdownlint" ]
}
