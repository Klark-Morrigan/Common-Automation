#!/usr/bin/env bash
# Prints how many times one project's files on a Nexus Mods page were
# downloaded, one line per version.
#
# A mod page can host files of several projects, each file named after its
# project. Only the files carrying the project's name count, in every category,
# archived included, since an archived file keeps its downloads. A version can
# ship as several files - a main file and an optional one - so its files are
# summed onto one line.
#
# totalDownloads is counted, not uniqueDownloads, to match GitHub, which
# counts every download.
#
# Reads fetch-nexus-files.sh's answer on stdin.
#
# Inputs are read from the environment:
#   NEXUS_FILE_NAME  the name a counted file carries.
#   NEXUS_LOCALE     optional locale of the build the page hosts. Empty, the
#                    files count under no locale.
#
# Prints to stdout one line per version, in source-summary.sh's format, in no
# promised order.
#
# Logs to stderr each file it counts, with its id, version and count, and each
# file it ignores.
#
# Exits non-zero, printing nothing to stdout, when stdin is not exactly one
# files answer or no file carries the name. A caller publishing from this output then keeps
# its last good figures rather than publishing zeroes.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../../lib/line-endings.sh
source "${repo_root}/.github/lib/line-endings.sh"

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

file_name="${NEXUS_FILE_NAME:-}"
locale="${NEXUS_LOCALE:-}"

require_value NEXUS_FILE_NAME "${file_name}"

if [[ -n "${locale}" ]]; then

    echo "Counting the Nexus files named '${file_name}', under locale ${locale}." >&2
else

    echo "Counting the Nexus files named '${file_name}', under no locale: NEXUS_LOCALE is unset." >&2
fi

# Marks every file counted or not, so the log can name what was ignored. This
# pass only reads the answer, so a failure here means stdin was not one.
# Slurped, so stdin must hold exactly one document: an empty stdin holds
# none, and a second answer would count every file twice.
# shellcheck disable=SC2310 # the condition is the failure check; pipefail carries jq's status
if ! classified_files=$(jq -sc --arg fileName "${file_name}" \
    'if length == 1 then .[0] else error("not one answer") end
     | .data.modFiles
     | if type == "array" then . else error("no file list") end
     | map({ fileId, name, version, category, count: .totalDownloads, counted: (.name == $fileName) })' \
    | strip_carriage_returns); then

    exit_with_error "stdin is not a Nexus files answer."
fi

jq -r '.[]
       | if .counted then
           "  counted file \(.fileId), version \(.version), \(.category): \(.count) downloads."
         else
           "  ignored file \(.fileId), \(.name) \(.version): its name does not match."
         end' \
    <<< "${classified_files}" | strip_carriage_returns >&2

summary=$(jq -r --arg locale "${locale}" \
    '[ .[] | select(.counted) ]
     | group_by(.version)[]
     | [ .[0].version, $locale, (map(.count) | add) ]
     | @tsv' \
    <<< "${classified_files}" | strip_carriage_returns)

if [[ -z "${summary}" ]]; then

    exit_with_error "no Nexus file is named '${file_name}'."
fi

summary_line_count="$(grep -c '' <<< "${summary}")"

echo "Summarised ${summary_line_count} lines, one per version." >&2
printf '%s\n' "${summary}"
