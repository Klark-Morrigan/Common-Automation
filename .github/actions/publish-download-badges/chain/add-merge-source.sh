#!/usr/bin/env bash
# Adds a source besides the GitHub releases to the merge. Sourced, not
# executed: defines add_merge_source.

# shellcheck source=SCRIPTDIR/../summaries/source-summary.sh
source "${BASH_SOURCE[0]%/*}/../summaries/source-summary.sh"

# shellcheck source=SCRIPTDIR/write-run-page-table.sh
source "${BASH_SOURCE[0]%/*}/write-run-page-table.sh"

# Shows the source's lines on the run's page under its name, then appends the
# source to MERGE_SOURCES as a <source name> <file> pair, as
# merge-release-downloads.sh takes its arguments.
#
# The table is written before the merge runs, so a run the merge refuses, such
# as for a version with no release, still shows what the source reported.
#   add_merge_source <source name> <file>
add_merge_source() {

    local source_name="$1"
    local source_file="$2"

    write_run_page_table "${source_name}" "${SOURCE_SUMMARY_FIELDS[@]}" < "${source_file}"

    MERGE_SOURCES+=("${source_name}" "${source_file}")
}
