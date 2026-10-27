#!/usr/bin/env bats
# Unit tests for log-rendered-file-changes.sh.
# Run with: bats .github/actions/publish-download-badges/badge-branch/log-rendered-file-changes.bats
#
# The changes arrive as git diff-tree --name-status prints them.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/log-rendered-file-changes.sh
source "${BATS_TEST_DIRNAME}/log-rendered-file-changes.sh"

@test "logs an added file as added, and a modified one as changed, both current" {

    run --separate-stderr log_rendered_file_changes \
        "$(printf 'A\tdownloads.json\nM\tlatest-version.json')" \
        "$(printf 'downloads.json\nlatest-version.json')"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$({
        write_log_table "File" "Change"
        write_log_row "" "downloads.json" current "added"
        write_log_row "" "latest-version.json" current "changed"
        write_log_table_end

    } 2>&1)" ]
}

@test "logs a file with no change line as unchanged, in plain words" {

    run --separate-stderr log_rendered_file_changes \
        "$(printf 'M\tdownloads.json')" \
        "$(printf 'downloads.json\nlatest-version.json')"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"$(write_log_row "" "latest-version.json" "" "unchanged" 2>&1)"* ]]
}

@test "logs every file unchanged when nothing changed" {

    run --separate-stderr log_rendered_file_changes "" "downloads.json"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$({
        write_log_table "File" "Change"
        write_log_row "" "downloads.json" "" "unchanged"
        write_log_table_end

    } 2>&1)" ]
}

@test "lists the rendered files alone, never a change line's file that was not rendered" {

    # A withdrawn file is refused before this logs, so its line names a file
    # the run did not render.
    run --separate-stderr log_rendered_file_changes \
        "$(printf 'D\tlatest-version.json')" \
        "downloads.json"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" != *"latest-version.json"* ]]
}
