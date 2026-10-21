#!/usr/bin/env bash
# Prints Nexus Mods' answer listing every file of one mod page, with each
# file's download count.
#
# A mod page can host files of several projects, and Nexus' own mod-level
# figure cannot be split by project or by version. The file list can. This is
# the one place that talks to Nexus: every stage that needs the files reads
# the answer it prints rather than asking again.
#
# Reads Nexus' public GraphQL API, which needs no key.
#
# Inputs are read from the environment:
#   NEXUS_GAME_ID  Nexus' id of the game the mod is for.
#   NEXUS_MOD_ID   the mod page's id within that game.
#   RETRY_*        optional retry tuning, read by retry.sh's retry_command.
#                  Default classifiers: RETRY_CLASSIFIER_SET_HTTP.
#
# Prints to stdout the answer as Nexus sent it: a JSON object whose
# data.modFiles holds one object per file, with its fileId, name, version,
# category and totalDownloads.
#
# Logs to stderr the ids it queries and how many files came back.
#
# Exits non-zero, printing nothing to stdout, when the request fails, the
# answer is not a JSON object, or it carries GraphQL errors. A caller
# publishing from this output then keeps its last good figures.

set -euo pipefail

readonly NEXUS_GRAPHQL_URL="https://api.nexusmods.com/v2/graphql"

# Every file of the page, archived ones included: an archived file keeps its
# downloads. The ids are variables, so no input is spliced into the query.
# shellcheck disable=SC2016 # the $names are GraphQL variables, not the shell's
readonly MOD_FILES_QUERY='query ModFiles($modId: ID!, $gameId: ID!) {
  modFiles(modId: $modId, gameId: $gameId) { fileId name version category totalDownloads }
}'

# curl sets no time limit of its own, so a stalled connection would hold the
# job until Actions cancels it. Each attempt is cut off instead, and retried.
readonly CONNECT_TIMEOUT_SECONDS=10
readonly REQUEST_TIMEOUT_SECONDS=60

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../../lib/line-endings.sh
source "${repo_root}/.github/lib/line-endings.sh"

# shellcheck source=SCRIPTDIR/../../../lib/retry.sh
source "${repo_root}/.github/lib/retry.sh"

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

game_id="${NEXUS_GAME_ID:-}"
mod_id="${NEXUS_MOD_ID:-}"

require_value NEXUS_GAME_ID "${game_id}"
require_value NEXUS_MOD_ID "${mod_id}"

request_body="$(jq -nc --arg query "${MOD_FILES_QUERY}" --arg modId "${mod_id}" --arg gameId "${game_id}" \
    '{ query: $query, variables: { modId: $modId, gameId: $gameId } }' | strip_carriage_returns)"

echo "Querying the files of Nexus mod ${mod_id} in game ${game_id}." >&2

answer_file="$(mktemp)"
trap 'rm -f "${answer_file}"' EXIT

# --fail turns an HTTP error into curl's exit status, with the status code in
# its error line, which is what the retry classifiers read.
RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_HTTP}}" \
    retry_or_exit_to_file "query the files of Nexus mod ${mod_id}" "${answer_file}" \
    curl --silent --show-error --fail \
    --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" --max-time "${REQUEST_TIMEOUT_SECONDS}" \
    --header "Content-Type: application/json" \
    --data "${request_body}" \
    "${NEXUS_GRAPHQL_URL}"

# jq -e fails on an empty answer too, which yields no value at all.
if ! jq -e 'type == "object"' < "${answer_file}" > /dev/null 2>&1; then

    exit_with_error "Nexus' answer for the files of mod ${mod_id} is not a JSON object."
fi

# GraphQL reports a bad query or an unknown argument as errors beside a null or
# partial data, under HTTP 200, so the status alone does not show it.
graphql_errors="$(jq -r '[ .errors // [] | .[] | .message // tostring ] | join("; ")' < "${answer_file}" \
    | strip_carriage_returns)"

if [[ -n "${graphql_errors}" ]]; then

    exit_with_error "Nexus answered the query for the files of mod ${mod_id} with errors: ${graphql_errors}"
fi

file_count="$(jq '.data.modFiles | length' < "${answer_file}" | strip_carriage_returns)"

echo "Nexus returned ${file_count} files for mod ${mod_id}." >&2
cat "${answer_file}"
