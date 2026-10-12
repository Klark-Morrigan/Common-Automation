#!/usr/bin/env bash
# Writes one badge figure as a shields endpoint file: the JSON that shields'
# endpoint badge fetches and draws.
#
# Sourced, not executed: defines write_badge_endpoint. Every renderer writes
# through it, so the endpoint schema and the look the badges share are set in
# one place.

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

# Writes the endpoint file, replacing any earlier one.
#   write_badge_endpoint <file> <label> <message>
write_badge_endpoint() {

    local file="${1:?write_badge_endpoint: file required}"
    local label="${2:?write_badge_endpoint: label required}"
    local message="${3:?write_badge_endpoint: message required}"
    local endpoint

    # jq builds the JSON so a label holding quotes or backslashes is escaped,
    # not spliced.
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
           cacheSeconds: $cacheSeconds }')"

    # A native Windows jq, the one Git Bash finds, ends its line with CRLF.
    # The file would then differ from one rendered on Linux for the same
    # figure, and read as a change to a caller that publishes only changes.
    printf '%s\n' "${endpoint//$'\r'/}" > "${file}"
}
