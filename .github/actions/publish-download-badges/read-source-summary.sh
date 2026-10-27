#!/usr/bin/env bash
# Reads one source's summary, checking every line against source-summary.sh's
# format. Sourced, not executed: defines read_source_summary.
#
# Every stage that reads a source's lines reads them here, so the format is
# checked in one place.

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${BASH_SOURCE[0]%/*}/../../lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/source-summary.sh
source "${BASH_SOURCE[0]%/*}/source-summary.sh"

# Reads the whole summary on stdin into SOURCE_SUMMARY_VERSIONS,
# SOURCE_SUMMARY_LOCALES and SOURCE_SUMMARY_COUNTS, one element per line, in
# line order.
#
# Empty input reads as no lines: a source can report nothing yet, such as a
# hand-kept ledger with no entry. Every line is read before the caller writes
# anything, so a bad line anywhere fails the caller with nothing written.
# Fails through exit_with_error, naming the source.
#   read_source_summary <source name> < summary
read_source_summary() {

    local source_name="$1"
    local source_line

    SOURCE_SUMMARY_VERSIONS=()
    SOURCE_SUMMARY_LOCALES=()
    SOURCE_SUMMARY_COUNTS=()

    # The `|| [[ -n ... ]]` keeps a last line that has no newline.
    while IFS= read -r source_line || [[ -n "${source_line}" ]]; do

        if [[ ! "${source_line}" =~ ${SOURCE_SUMMARY_LINE_REGEX} ]]; then
            exit_with_error "${source_name}: '${source_line}' is not a source summary line."
        fi

        SOURCE_SUMMARY_VERSIONS+=("${BASH_REMATCH[1]}")
        SOURCE_SUMMARY_LOCALES+=("${BASH_REMATCH[2]}")

        # 10# reads a leading zero as decimal; bash would take it for octal.
        SOURCE_SUMMARY_COUNTS+=("$(( 10#${BASH_REMATCH[3]} ))")
    done
}
