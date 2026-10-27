#!/usr/bin/env bash
# Writes one badge figure as a shields endpoint file: the JSON that shields'
# endpoint badge fetches and draws.
#
# Sourced, not executed: defines write_badge_endpoint. Every renderer writes
# through it, so the endpoint schema and the look the badges share are set in
# one place.

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this file's location.
# Prefixed, since a sourced file's variables land in its caller.
_badge_endpoint_repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../../lib/line-endings.sh
source "${_badge_endpoint_repo_root}/.github/lib/line-endings.sh"

# The roles its message names.
# shellcheck source=SCRIPTDIR/../../../lib/log-records/log-record-format.sh
source "${_badge_endpoint_repo_root}/.github/lib/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../../lib/log-records/writers/write-log-message.sh
source "${_badge_endpoint_repo_root}/.github/lib/log-records/writers/write-log-message.sh"

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${_badge_endpoint_repo_root}/.github/lib/workflow-commands.sh"

# The only version of shields' endpoint schema.
BADGE_SCHEMA_VERSION=1

# Shields' colour for a download count above zero, so the badges keep the look
# of the github/downloads badges they replace.
BADGE_COLOR="brightgreen"

# How long shields may serve a fetched figure before fetching it again. Five
# minutes is the shortest shields honours; it ignores anything lower. Any
# longer and shields keeps showing an old figure after the branch has a new
# one, which hides a new release's early downloads while they happen.
BADGE_CACHE_SECONDS=300

# Writes the endpoint file, replacing any earlier one, and logs it to stderr
# as a log record, so every renderer logs its output the same way. The message
# is logged as plain words: it is a count for one figure, a rate or a list for
# another. Fails through exit_with_error when an argument is empty.
#   write_badge_endpoint <file> <label> <message>
write_badge_endpoint() {

    local file="${1:-}"
    local label="${2:-}"
    local message="${3:-}"
    local endpoint

    require_value "endpoint file" "${file}"
    require_value "badge label" "${label}"
    require_value "badge message" "${message}"

    # jq builds the JSON so a label holding quotes or backslashes is escaped,
    # not spliced.
    # shellcheck disable=SC2312 # the renderers sourcing this run under pipefail
    endpoint="$(jq -cn \
        --argjson schemaVersion "${BADGE_SCHEMA_VERSION}" \
        --arg label "${label}" \
        --arg message "${message}" \
        --arg color "${BADGE_COLOR}" \
        --argjson cacheSeconds "${BADGE_CACHE_SECONDS}" \
        '{ schemaVersion: $schemaVersion,
           label: $label,
           message: $message,
           color: $color,
           cacheSeconds: $cacheSeconds }' \
        | strip_carriage_returns)"

    printf '%s\n' "${endpoint}" > "${file}"

    write_log_message \
        "${LOG_ROLE_PLAIN}" "Wrote " \
        "${LOG_ROLE_ID}" "${file##*/}" \
        "${LOG_ROLE_PLAIN}" ": label '" \
        "${LOG_ROLE_ID}" "${label}" \
        "${LOG_ROLE_PLAIN}" "', message '${message}'."
}
