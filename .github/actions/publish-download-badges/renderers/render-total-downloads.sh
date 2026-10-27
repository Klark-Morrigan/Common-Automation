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
# and the file to stderr, as log records.
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
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../../.." && pwd)}"

# The roles its message names.
# shellcheck source=SCRIPTDIR/../../../lib/log-records/log-record-format.sh
source "${repo_root}/.github/lib/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../../lib/log-records/writers/write-log-records.sh
source "${repo_root}/.github/lib/log-records/writers/write-log-records.sh"

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/badge-endpoint.sh
source "${script_dir}/badge-endpoint.sh"

# shellcheck source=SCRIPTDIR/../release-summary.sh
source "${script_dir}/../release-summary.sh"

label="${1:-}"
output_dir="${2:-}"

require_value "label" "${label}"
require_value "output directory" "${output_dir}"

if [[ ! -d "${output_dir}" ]]; then

    exit_with_error "output directory '${output_dir}' does not exist."
fi

read_release_summary

total_downloads=0

for download_count in "${RELEASE_SUMMARY_COUNTS[@]}"; do
    total_downloads=$(( total_downloads + download_count ))
done

write_log_message \
    "${LOG_ROLE_PLAIN}" "Summed " \
    "${LOG_ROLE_COUNT}" "${#RELEASE_SUMMARY_COUNTS[@]}" \
    "${LOG_ROLE_PLAIN}" " lines, one per release and locale: " \
    "${LOG_ROLE_COUNT}" "${total_downloads}" \
    "${LOG_ROLE_PLAIN}" " downloads."

write_badge_endpoint "${output_dir}/${ENDPOINT_FILE_NAME}" "${label}" "${total_downloads}"
