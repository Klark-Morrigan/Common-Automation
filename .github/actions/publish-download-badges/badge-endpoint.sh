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
_badge_endpoint_repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../lib/line-endings.sh
source "${_badge_endpoint_repo_root}/.github/lib/line-endings.sh"

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

# Writes the endpoint file, replacing any earlier one, and logs it to stderr,
# so every renderer logs its output the same way.
#   write_badge_endpoint <file> <label> <message>
write_badge_endpoint() {

    local file="${1:?write_badge_endpoint: file required}"
    local label="${2:?write_badge_endpoint: label required}"
    local message="${3:?write_badge_endpoint: message required}"
    local endpoint

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

    echo "Wrote ${file##*/}: label '${label}', message '${message}'." >&2
}
