#!/usr/bin/env bash
# Reads one source's summary, checking every line against source-summary.sh's
# format. Sourced, not executed: defines read_source_summary.
#
# Every stage that reads a source's lines reads them here, so the format is
# checked in one place.

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/read-summary-lines.sh
source "${BASH_SOURCE[0]%/*}/read-summary-lines.sh"

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
# shellcheck disable=SC2034 # the arrays are read by the scripts that source this file
read_source_summary() {

    local source_name="$1"

    SOURCE_SUMMARY_VERSIONS=()
    SOURCE_SUMMARY_LOCALES=()
    SOURCE_SUMMARY_COUNTS=()

    if ! read_summary_lines "${SOURCE_SUMMARY_LINE_REGEX}" \
        SOURCE_SUMMARY_VERSIONS SOURCE_SUMMARY_LOCALES SOURCE_SUMMARY_COUNTS; then

        exit_with_error "${source_name}: '${UNMATCHED_SUMMARY_LINE}' is not a source summary line."
    fi
}
