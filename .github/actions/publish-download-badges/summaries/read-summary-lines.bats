#!/usr/bin/env bats
# Unit tests for read-summary-lines.sh.
# Run with: bats .github/actions/publish-download-badges/summaries/read-summary-lines.bats
#
# The cases read a two-field format of their own, a name and a count, so they
# hold the loop to no one summary's fields.

# shellcheck source=SCRIPTDIR/read-summary-lines.sh
source "${BATS_TEST_DIRNAME}/read-summary-lines.sh"

LINE_REGEX=$'^([^\t]+)\t([0-9]+)$'

# Empties NAMES and COUNTS, as a caller does, then reads stdin into them.
read_names_and_counts() {

    NAMES=()
    COUNTS=()

    read_summary_lines "${LINE_REGEX}" NAMES COUNTS
}

@test "reads each capture group into its array, in line order" {

    read_names_and_counts <<< $'a\t1\nb\t2'

    [ "${NAMES[*]}" = "a b" ]
    [ "${COUNTS[*]}" = "1 2" ]
}

@test "reads the last field with a leading zero as decimal" {

    read_names_and_counts <<< $'a\t010'

    [ "${COUNTS[0]}" = "10" ]
}

@test "reads a last line that has no newline" {

    # Not a here-string: it always ends in a newline.
    read_names_and_counts < <(printf 'a\t1\nb\t2')

    [ "${COUNTS[*]}" = "1 2" ]
}

@test "reads empty stdin as no lines" {

    read_names_and_counts < /dev/null

    [ "${#NAMES[@]}" -eq 0 ]
    [ "${#COUNTS[@]}" -eq 0 ]
}

@test "returns 1 at a line that does not match, leaving it for the caller to name" {

    local read_status=0

    read_names_and_counts <<< $'a\t1\nb\tx\nc\t3' || read_status=$?

    [ "${read_status}" -eq 1 ]
    [ "${UNMATCHED_SUMMARY_LINE}" = $'b\tx' ]
    [ "${NAMES[*]}" = "a" ]
}

@test "clears the unmatched line a failed read left" {

    read_names_and_counts <<< $'b\tx' || true
    read_names_and_counts <<< $'a\t1'

    [ -z "${UNMATCHED_SUMMARY_LINE}" ]
}
