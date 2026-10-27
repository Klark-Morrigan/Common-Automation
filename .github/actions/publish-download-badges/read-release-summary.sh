#!/usr/bin/env bash
# Reads a release summary, checking every line against release-summary.sh's
# format. Sourced, not executed: defines read_release_summary.
#
# Every stage that reads the summary reads it here, so the format is checked
# in one place.

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${BASH_SOURCE[0]%/*}/../../lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/release-summary.sh
source "${BASH_SOURCE[0]%/*}/release-summary.sh"

# Reads the whole summary on stdin into RELEASE_SUMMARY_TAGS,
# RELEASE_SUMMARY_PUBLISHED_TIMES, RELEASE_SUMMARY_LOCALES and
# RELEASE_SUMMARY_COUNTS, one element per line, in line order.
#
# Every line is read before the caller writes anything, so a bad line anywhere
# fails the caller with nothing written. Fails through exit_with_error, so the
# annotation names the script that read the bad summary.
#   read_release_summary < summary
read_release_summary() {

    local summary_line

    RELEASE_SUMMARY_TAGS=()
    RELEASE_SUMMARY_PUBLISHED_TIMES=()
    RELEASE_SUMMARY_LOCALES=()
    RELEASE_SUMMARY_COUNTS=()

    # The `|| [[ -n ... ]]` keeps a last line that has no newline.
    while IFS= read -r summary_line || [[ -n "${summary_line}" ]]; do

        if [[ ! "${summary_line}" =~ ${RELEASE_SUMMARY_LINE_REGEX} ]]; then

            exit_with_error "'${summary_line}' is not a release summary line."
        fi

        RELEASE_SUMMARY_TAGS+=("${BASH_REMATCH[1]}")
        RELEASE_SUMMARY_PUBLISHED_TIMES+=("${BASH_REMATCH[2]}")
        RELEASE_SUMMARY_LOCALES+=("${BASH_REMATCH[3]}")

        # 10# reads a leading zero as decimal; bash would take it for octal.
        RELEASE_SUMMARY_COUNTS+=("$(( 10#${BASH_REMATCH[4]} ))")
    done

    if (( ${#RELEASE_SUMMARY_TAGS[@]} == 0 )); then

        exit_with_error "no release summary on stdin."
    fi
}
