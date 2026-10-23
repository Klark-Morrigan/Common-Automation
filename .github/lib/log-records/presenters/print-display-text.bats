#!/usr/bin/env bats
# Unit tests for print-display-text.sh.
# Run with: bats .github/lib/log-records/presenters/print-display-text.bats

# shellcheck source=SCRIPTDIR/print-display-text.sh
source "${BATS_TEST_DIRNAME}/print-display-text.sh"

setup() {

    # A tester's own colour settings must not reach the assertions.
    unset NO_COLOR FORCE_COLOR
}

@test "prints the text in its role's colour under FORCE_COLOR, with no newline" {

    FORCE_COLOR=1 run print_display_text count "120"

    [ "${status}" -eq 0 ]
    [ "${output}" = $'\033[32m120\033[0m' ]
}

@test "prints a plain role's text uncoloured under FORCE_COLOR" {

    FORCE_COLOR=1 run print_display_text "" "plain words"

    [ "${status}" -eq 0 ]
    [ "${output}" = "plain words" ]
}

@test "prints uncoloured when stdout is not a terminal" {

    run print_display_text count "120"

    [ "${status}" -eq 0 ]
    [ "${output}" = "120" ]
}

@test "prints the display text it is given, without resolving it again" {

    run print_display_text locale "en"

    [ "${status}" -eq 0 ]
    [ "${output}" = "en" ]
}
