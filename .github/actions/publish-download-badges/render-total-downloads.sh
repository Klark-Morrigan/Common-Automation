#!/usr/bin/env bash
# Writes the total-downloads badge: the counted downloads of every release,
# summed.
#
# Usage: render-total-downloads.sh <label> <output-dir> < summary
#
# Reads summarise-release-downloads.sh's output on stdin, one release per line:
#   <tag>  <published_at>  <download count>
# Writes downloads.json into <output-dir>, which must exist.
#
# The message is the plain integer. Shields' own 5.6k abbreviation hides the
# difference between 500 and 599, which at these counts is most of the signal.
#
# Exits non-zero, writing nothing, when stdin holds no release or a line is not
# a summary line. A caller publishing from <output-dir> then keeps its last good
# figure rather than publishing a zero.

set -euo pipefail

readonly SCRIPT_NAME="render-total-downloads"

readonly ENDPOINT_FILE_NAME="downloads.json"

# Tag, publish time, count. The count is captured.
readonly SUMMARY_LINE_REGEX=$'^[^\t]+\t[^\t]+\t([0-9]+)$'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./badge-endpoint.sh
source "${script_dir}/badge-endpoint.sh"

label="${1:?${SCRIPT_NAME}: label required}"
output_dir="${2:?${SCRIPT_NAME}: output directory required}"

if [[ ! -d "${output_dir}" ]]; then

    echo "::error::${SCRIPT_NAME}: output directory '${output_dir}' does not exist." >&2
    exit 1
fi

total_downloads=0
release_count=0

# The `|| [[ -n ... ]]` keeps a last line that has no newline.
while IFS= read -r summary_line || [[ -n "${summary_line}" ]]; do

    if [[ ! "${summary_line}" =~ ${SUMMARY_LINE_REGEX} ]]; then

        echo "::error::${SCRIPT_NAME}: '${summary_line}' is not a release summary line." >&2
        exit 1
    fi

    # 10# reads a leading zero as decimal; bash would take it for octal.
    total_downloads=$(( total_downloads + 10#${BASH_REMATCH[1]} ))
    release_count=$(( release_count + 1 ))
done

if (( release_count == 0 )); then

    echo "::error::${SCRIPT_NAME}: no release summary on stdin." >&2
    exit 1
fi

write_badge_endpoint "${output_dir}/${ENDPOINT_FILE_NAME}" "${label}" "${total_downloads}"
