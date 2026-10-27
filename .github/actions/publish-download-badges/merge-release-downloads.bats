#!/usr/bin/env bats
# Unit tests for merge-release-downloads.sh.
# Run with: bats .github/actions/publish-download-badges/merge-release-downloads.bats
#
# The GitHub summary arrives on stdin and each source in a file, as the
# publish action hands them over. The summary reader and the log writers run
# for real, so each case asserts the lines a renderer would read.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

# shellcheck source=SCRIPTDIR/source-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/source-summary-fixtures.bash"

# The expected log records come from the writers the merge calls.
# shellcheck source=SCRIPTDIR/../../lib/log-records/writers/write-log-records.sh
source "${BATS_TEST_DIRNAME}/../../lib/log-records/writers/write-log-records.sh"

SCRIPT="${BATS_TEST_DIRNAME}/merge-release-downloads.sh"

setup() {

    NEXUS_FILE="${BATS_TEST_TMPDIR}/nexus.tsv"
    FOSSIC_FILE="${BATS_TEST_TMPDIR}/fossic.tsv"
}

# Writes the given lines, each ended by a newline, to a source file.
#   write_source_file <file> <line...>
write_source_file() {

    local file="$1"

    shift

    printf '%s\n' "$@" > "${file}"
}

# Runs the merge with the given summary on stdin and the remaining arguments
# as its source pairs.
#   merge <summary> [<source name> <file>]...
merge() {

    local summary="$1"

    shift

    run --separate-stderr "${SCRIPT}" "$@" <<< "${summary}"
}

@test "passes the summary through unchanged with no other source" {

    local summary

    summary="$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)"

    merge "${summary}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${summary}" ]
    [ "${stderr}" = "$(write_log_message "" "No other source: the summary passes through unchanged." 2>&1)" ]
}

@test "adds a source's count to the line of its tag and locale" {

    write_source_file "${NEXUS_FILE}" "$(build_source_summary_line 1.2.3 en 7)"

    merge "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" Nexus "${NEXUS_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 47)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" ]
}

@test "adds two sources to the same line" {

    write_source_file "${NEXUS_FILE}" "$(build_source_summary_line 1.2.3 zh-hans 7)"
    write_source_file "${FOSSIC_FILE}" "$(build_source_summary_line 1.2.3 zh-hans 120)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" \
        Nexus "${NEXUS_FILE}" \
        Fossic "${FOSSIC_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 142)" ]
}

@test "gives a locale new to a release a line of its own, placed by locale" {

    # en sorts before the release's only GitHub locale, and ru after it, so
    # neither lands by being appended.
    write_source_file "${FOSSIC_FILE}" \
        "$(build_source_summary_line 1.2.3 zh-hans 120)" \
        "$(build_source_summary_line 1.2.3 en 5)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z ru 15)" Fossic "${FOSSIC_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 5)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z ru 15)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 120)" ]
}

@test "orders locales byte by byte, as the summary does" {

    # A dictionary collation skips the hyphen and puts zha first.
    write_source_file "${FOSSIC_FILE}" "$(build_source_summary_line 1.2.3 zha 5)"

    LC_ALL=en_US.UTF-8 merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" Fossic "${FOSSIC_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zha 5)" ]
}

@test "keeps GitHub's release order and publish times" {

    # A hotfix published after a higher version, and the source listing its
    # versions in tag order, so a merge ordering by either would show.
    write_source_file "${NEXUS_FILE}" \
        "$(build_source_summary_line 1.1.1 en 2)" \
        "$(build_source_summary_line 1.2.0 en 4)"

    merge "$(build_summary_line 1.1.1 2026-09-20T00:00:00Z en 1)
$(build_summary_line 1.2.0 2026-09-10T00:00:00Z en 10)" Nexus "${NEXUS_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.1.1 2026-09-20T00:00:00Z en 3)
$(build_summary_line 1.2.0 2026-09-10T00:00:00Z en 14)" ]
}

@test "joins a source line with no locale to the release's line with none" {

    write_source_file "${NEXUS_FILE}" "$(build_source_summary_line 1.2.3 "" 7)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 40)" Nexus "${NEXUS_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 47)" ]
}

@test "reads a source count with a leading zero as decimal" {

    write_source_file "${NEXUS_FILE}" "$(build_source_summary_line 1.2.3 en 010)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" Nexus "${NEXUS_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 50)" ]
}

@test "reads a source's last line that has no newline" {

    printf '%s' "$(build_source_summary_line 1.2.3 en 7)" > "${NEXUS_FILE}"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" Nexus "${NEXUS_FILE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 47)" ]
}

@test "logs each source line, the line it joined or created, then the merge" {

    write_source_file "${NEXUS_FILE}" "$(build_source_summary_line 1.2.3 en 7)"
    write_source_file "${FOSSIC_FILE}" "$(build_source_summary_line 1.2.3 zh-hans 120)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" \
        Nexus "${NEXUS_FILE}" \
        Fossic "${FOSSIC_FILE}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$({
        write_log_table Source Release Locale Downloads Line
        write_log_row "" Nexus "" 1.2.3 locale en count 7 "" joined
        write_log_row "" Fossic "" 1.2.3 locale zh-hans count 120 "" created
        write_log_table_end
        write_log_message \
            "" "Merged " count 2 "" " lines from " count 2 "" " sources into " count 2 "" " summary lines."

    } 2>&1)" ]
}

@test "fails, printing nothing, when a version matches no release" {

    write_source_file "${NEXUS_FILE}" \
        "$(build_source_summary_line 1.2.3 en 7)" \
        "$(build_source_summary_line 1.2.30 en 2)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" Nexus "${NEXUS_FILE}"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"merge-release-downloads: Nexus: version 1.2.30 matches no release."* ]]
}

@test "fails, printing nothing, on a malformed source line" {

    write_source_file "${NEXUS_FILE}" "$(build_source_summary_line 1.2.3 en 4x)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" Nexus "${NEXUS_FILE}"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"Nexus: '1.2.3"*"' is not a source summary line."* ]]
}

@test "fails, printing nothing, on a malformed summary line" {

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 4x)"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"merge-release-downloads: '1.2.3"*"' is not a release summary line."* ]]
}

@test "fails when a source file cannot be read" {

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" Nexus "${BATS_TEST_TMPDIR}/missing.tsv"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"Nexus: cannot read '${BATS_TEST_TMPDIR}/missing.tsv'."* ]]
}

@test "fails when a source name has no file" {

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" Nexus

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"sources come as <source name> <file> pairs, but an odd number of arguments was given."* ]]
}

@test "requires the source name" {

    write_source_file "${NEXUS_FILE}" "$(build_source_summary_line 1.2.3 en 7)"

    merge "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" "" "${NEXUS_FILE}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"source name is required"* ]]
}
