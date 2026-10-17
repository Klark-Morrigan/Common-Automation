#!/usr/bin/env bats
# Unit tests for write-step-summary-table.sh.
# Run with: bats .github/actions/publish-download-badges/write-step-summary-table.bats
#
# GITHUB_STEP_SUMMARY points at a file in the test's own directory, so each
# case asserts the Markdown the run page would render.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/write-step-summary-table.sh"

setup() {

    export GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/step-summary.md"
}

# Runs the script with the given lines on stdin.
#   write_table <lines> <heading> <column name...>
write_table() {

    local lines="$1"

    shift

    run --separate-stderr "${SCRIPT}" "$@" <<< "${lines}"
}

@test "writes each line as a row under the heading and the header row" {

    write_table "$(printf '1.2.4\ten\t3\n1.2.3\tzh-hans\t40')" "Downloads" release locale downloads

    [ "${status}" -eq 0 ]
    [ "$(cat "${GITHUB_STEP_SUMMARY}")" = "## Downloads

| release | locale | downloads |
| --- | --- | --- |
| 1.2.4 | en | 3 |
| 1.2.3 | zh-hans | 40 |" ]
}

@test "ends the table with a blank line" {

    write_table "$(printf '1.2.3\t40')" "Downloads" release downloads

    # The trailing dot keeps the command substitution from dropping the
    # newlines under test.
    local summary
    summary="$(cat "${GITHUB_STEP_SUMMARY}"; printf '.')"

    [ "${status}" -eq 0 ]
    [[ "${summary}" == *$'| 40 |\n\n.' ]]
}

@test "keeps an empty field in its own column" {

    write_table "$(printf '1.2.3\t\t40')" "Downloads" release locale downloads

    [ "${status}" -eq 0 ]
    [ "$(sed -n 5p "${GITHUB_STEP_SUMMARY}")" = "| 1.2.3 |  | 40 |" ]
}

@test "escapes a | in a cell" {

    write_table "$(printf 'a|b\t40')" "Downloads" "re|lease" downloads

    [ "${status}" -eq 0 ]
    [ "$(sed -n 3p "${GITHUB_STEP_SUMMARY}")" = '| re\|lease | downloads |' ]
    [ "$(sed -n 5p "${GITHUB_STEP_SUMMARY}")" = '| a\|b | 40 |' ]
}

@test "appends to an existing summary rather than overwriting it" {

    printf 'Earlier step.\n' > "${GITHUB_STEP_SUMMARY}"

    write_table "$(printf '1.2.3\t40')" "Downloads" release downloads

    [ "${status}" -eq 0 ]
    [ "$(cat "${GITHUB_STEP_SUMMARY}")" = "Earlier step.
## Downloads

| release | downloads |
| --- | --- |
| 1.2.3 | 40 |" ]
}

@test "writes the heading and the header row alone on empty input" {

    # Not through write_table: a here-string always carries a newline, which
    # reads as one blank line rather than as no input.
    run --separate-stderr "${SCRIPT}" "Downloads" release downloads < /dev/null

    [ "${status}" -eq 0 ]
    [ "$(cat "${GITHUB_STEP_SUMMARY}")" = "## Downloads

| release | downloads |
| --- | --- |" ]
}

@test "writes a last line that has no newline" {

    # Not through write_table: a here-string always ends in a newline.
    run --separate-stderr "${SCRIPT}" "Downloads" release downloads < <(printf '1.2.4\t3\n1.2.3\t40')

    [ "${status}" -eq 0 ]
    [ "$(sed -n 6p "${GITHUB_STEP_SUMMARY}")" = "| 1.2.3 | 40 |" ]
}

@test "logs the heading and its row count, to stderr alone" {

    write_table "$(printf '1.2.4\t3\n1.2.3\t40')" "Downloads" release downloads

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "Wrote table 'Downloads' to the job summary: 2 rows." ]
}

@test "fails and writes nothing when a line has too few fields" {

    # The bad line comes last, so a table written row by row would already be
    # in the file.
    write_table "$(printf '1.2.4\ten\t3\n1.2.3\t40')" "Downloads" release locale downloads

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"'1.2.3"$'\t'"40' holds 2 fields; table 'Downloads' has 3 columns"* ]]
    [ ! -e "${GITHUB_STEP_SUMMARY}" ]
}

@test "fails and writes nothing when a line has too many fields" {

    write_table "$(printf '1.2.3\ten\t40')" "Downloads" release downloads

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"holds 3 fields; table 'Downloads' has 2 columns"* ]]
    [ ! -e "${GITHUB_STEP_SUMMARY}" ]
}

@test "fails when GITHUB_STEP_SUMMARY is unset" {

    unset GITHUB_STEP_SUMMARY

    write_table "$(printf '1.2.3\t40')" "Downloads" release downloads

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"GITHUB_STEP_SUMMARY is required"* ]]
}

@test "requires the heading" {

    write_table "$(printf '1.2.3\t40')" "" release downloads

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"heading is required"* ]]
    [ ! -e "${GITHUB_STEP_SUMMARY}" ]
}

@test "requires a column name" {

    write_table "$(printf '1.2.3\t40')" "Downloads"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"at least one column name is required"* ]]
    [ ! -e "${GITHUB_STEP_SUMMARY}" ]
}
