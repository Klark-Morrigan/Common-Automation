#!/usr/bin/env bats
# Unit tests for print-section-heading.sh.
# Run with: bats .github/lib/print-section-heading.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

setup() {

    # shellcheck source=SCRIPTDIR/print-section-heading.sh
    source "${BATS_TEST_DIRNAME}/print-section-heading.sh"
}

@test "prints the title between the heading's rules, to stdout alone" {

    run --separate-stderr print_section_heading "bats"

    [ "${status}" -eq 0 ]
    [ "${output}" = "=== bats ===" ]
    [ -z "${stderr}" ]
}

@test "joins a title given as several words with spaces" {

    run print_section_heading "shellcheck" "runners" "(scripts)"

    [ "${output}" = "=== shellcheck runners (scripts) ===" ]
}
