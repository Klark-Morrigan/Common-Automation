#!/usr/bin/env bash
# Writes the total-downloads badge: the counted downloads of every release and
# locale, summed.
#
# Usage: render-total-downloads.sh <label> <output-dir> < summary
#
# Reads summarise-release-downloads.sh's output on stdin, in release-summary.sh's
# format.
#
# Writes downloads.json into <output-dir>, which must exist, and logs the sum
# and the file to stderr.
#
# The message is the plain integer. Shields' own 5.6k abbreviation hides the
# difference between 500 and 599, which at these counts is most of the signal.
#
# Exits non-zero, writing nothing, when stdin holds no release or a line is not
# a summary line. A caller publishing from <output-dir> then keeps its last good
# figure rather than publishing a zero.

set -euo pipefail

readonly ENDPOINT_FILE_NAME="downloads.json"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/badge-endpoint.sh
source "${script_dir}/badge-endpoint.sh"

# shellcheck source=SCRIPTDIR/release-summary.sh
source "${script_dir}/release-summary.sh"

label="${1:-}"
output_dir="${2:-}"

require_value "label" "${label}"
require_value "output directory" "${output_dir}"

if [[ ! -d "${output_dir}" ]]; then

    exit_with_error "output directory '${output_dir}' does not exist."
fi

total_downloads=0
summary_line_count=0

# The `|| [[ -n ... ]]` keeps a last line that has no newline.
while IFS= read -r summary_line || [[ -n "${summary_line}" ]]; do

    if [[ ! "${summary_line}" =~ ${RELEASE_SUMMARY_LINE_REGEX} ]]; then

        exit_with_error "'${summary_line}' is not a release summary line."
    fi

    # 10# reads a leading zero as decimal; bash would take it for octal.
    total_downloads=$(( total_downloads + 10#${BASH_REMATCH[1]} ))
    summary_line_count=$(( summary_line_count + 1 ))
done

if (( summary_line_count == 0 )); then

    exit_with_error "no release summary on stdin."
fi

echo "Summed ${summary_line_count} lines, one per release and locale: ${total_downloads} downloads." >&2

write_badge_endpoint "${output_dir}/${ENDPOINT_FILE_NAME}" "${label}" "${total_downloads}"
