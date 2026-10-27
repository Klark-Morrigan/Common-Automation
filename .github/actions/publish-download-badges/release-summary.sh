#!/usr/bin/env bash
# The release summary's line format: what summarise-release-downloads.sh
# prints and every later stage reads. Sourced, not executed: defines
# RELEASE_SUMMARY_FIELDS, RELEASE_SUMMARY_LINE_REGEX and read_release_summary.
#
# One tab-separated line per release and locale. Stating the format here lets
# the stages that read it, and the run page's table of it, agree without each
# restating it. Reading it here checks it in one place for every stage.
#
# Not readonly: a script may source this file more than once.

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${BASH_SOURCE[0]%/*}/../../lib/workflow-commands.sh"

# The fields in line order, named as the run page's table heads its columns.
# The locale field is empty for a count under no locale.
# shellcheck disable=SC2034 # read by the scripts that source this file
RELEASE_SUMMARY_FIELDS=(release published locale downloads)

# A whole line, capturing each field in line order. The locale may be empty,
# from a project keeping no locales.
# shellcheck disable=SC2034 # read by the scripts that source this file
RELEASE_SUMMARY_LINE_REGEX=$'^([^\t]+)\t([^\t]+)\t([^\t]*)\t([0-9]+)$'

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
