#!/usr/bin/env bash
# Reads a log record's kind. Sourced, not executed: defines
# resolve_record_kind.
#
# A reader that only routes a record needs its kind alone, so this takes the
# field after the marker without splitting the whole record.

# shellcheck source=SCRIPTDIR/log-record-format.sh
source "${BASH_SOURCE[0]%/*}/log-record-format.sh"

# Leaves the record's kind in record_kind, or nothing when the line is not a
# record.
#   resolve_record_kind <line>
resolve_record_kind() {

    local record_start="${LOG_RECORD_MARKER}${LOG_RECORD_SEPARATOR}"

    record_kind=""

    if [[ "$1" != "${record_start}"* ]]; then

        return 0
    fi

    record_kind="${1#"${record_start}"}"
    record_kind="${record_kind%%"${LOG_RECORD_SEPARATOR}"*}"
}
