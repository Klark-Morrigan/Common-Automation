#!/usr/bin/env bats
# Unit tests for read-source-summary.sh.
# Run with: bats .github/actions/publish-download-badges/summaries/read-source-summary.bats
#
# read-summary-lines.sh runs for real: the format it is handed is what these
# cases read back.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/read-source-summary.sh
source "${BATS_TEST_DIRNAME}/read-source-summary.sh"

# shellcheck source=SCRIPTDIR/source-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/source-summary-fixtures.bash"

@test "reads each line's fields in line order" {

    read_source_summary Nexus <<< "$(build_source_summary_line 1.2.4 zh-hans 3)
$(build_source_summary_line 1.2.3 en 40)"

    [ "${SOURCE_SUMMARY_VERSIONS[*]}" = "1.2.4 1.2.3" ]
    [ "${SOURCE_SUMMARY_LOCALES[*]}" = "zh-hans en" ]
    [ "${SOURCE_SUMMARY_COUNTS[*]}" = "3 40" ]
}

@test "reads an empty locale as no locale" {

    read_source_summary Nexus <<< "$(build_source_summary_line 1.2.3 "" 40)"

    [ "${#SOURCE_SUMMARY_LOCALES[@]}" -eq 1 ]
    [ "${SOURCE_SUMMARY_LOCALES[0]}" = "" ]
}

@test "reads a count with a leading zero as decimal" {

    read_source_summary Nexus <<< "$(build_source_summary_line 1.2.3 en 010)"

    [ "${SOURCE_SUMMARY_COUNTS[0]}" = "10" ]
}

@test "reads a last line that has no newline" {

    # Not a here-string: it always ends in a newline.
    read_source_summary Nexus < <(printf '1.2.4\ten\t3\n1.2.3\ten\t40')

    [ "${SOURCE_SUMMARY_COUNTS[*]}" = "3 40" ]
}

@test "reads empty stdin as no lines" {

    # A source can report nothing yet, such as a ledger with no entry.
    read_source_summary Fossic < /dev/null

    [ "${#SOURCE_SUMMARY_VERSIONS[@]}" -eq 0 ]
}

@test "replaces what an earlier read left" {

    read_source_summary Nexus <<< "$(build_source_summary_line 1.2.4 en 3)"
    read_source_summary Fossic < /dev/null

    [ "${#SOURCE_SUMMARY_VERSIONS[@]}" -eq 0 ]
}

@test "fails on a malformed line, naming the source" {

    run --separate-stderr read_source_summary Nexus <<< "$(build_source_summary_line 1.2.4 en 3)
$(build_source_summary_line 1.2.3 en 4x)"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"Nexus: '1.2.3"*"' is not a source summary line."* ]]
}

@test "fails on a blank line" {

    run --separate-stderr read_source_summary Nexus <<< "$(build_source_summary_line 1.2.4 en 3)

$(build_source_summary_line 1.2.3 en 40)"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"Nexus: '' is not a source summary line."* ]]
}
