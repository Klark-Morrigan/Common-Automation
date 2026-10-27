#!/usr/bin/env bash
# Reads a release summary, checking every line against release-summary.sh's
# format. Sourced, not executed: defines read_release_summary.
#
# Every stage that reads the summary reads it here, so the format is checked
# in one place.

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/read-summary-lines.sh
source "${BASH_SOURCE[0]%/*}/read-summary-lines.sh"

# shellcheck source=SCRIPTDIR/release-summary.sh
source "${BASH_SOURCE[0]%/*}/release-summary.sh"

# Reads the whole summary on stdin into RELEASE_SUMMARY_TAGS,
# RELEASE_SUMMARY_PUBLISHED_TIMES, RELEASE_SUMMARY_LOCALES and
# RELEASE_SUMMARY_COUNTS, one element per line, in line order.
#
# Every line is read before the caller writes anything, so a bad line anywhere
# fails the caller with nothing written. Empty input fails too: a summary
# always holds a release. Fails through exit_with_error, so the annotation
# names the script that read the bad summary.
#   read_release_summary < summary
# shellcheck disable=SC2034 # the arrays are read by the scripts that source this file
read_release_summary() {

    RELEASE_SUMMARY_TAGS=()
    RELEASE_SUMMARY_PUBLISHED_TIMES=()
    RELEASE_SUMMARY_LOCALES=()
    RELEASE_SUMMARY_COUNTS=()

    if ! read_summary_lines "${RELEASE_SUMMARY_LINE_REGEX}" \
        RELEASE_SUMMARY_TAGS RELEASE_SUMMARY_PUBLISHED_TIMES RELEASE_SUMMARY_LOCALES RELEASE_SUMMARY_COUNTS; then

        exit_with_error "'${UNMATCHED_SUMMARY_LINE}' is not a release summary line."
    fi

    if (( ${#RELEASE_SUMMARY_TAGS[@]} == 0 )); then
        exit_with_error "no release summary on stdin."
    fi
}
