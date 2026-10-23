#!/usr/bin/env bash
# Writes one log record to stderr. Sourced, not executed: defines
# write_log_record, which every write_log_* writer calls, so the line format
# is written in one place.
#
# stderr, because stdout carries the data a stage hands the next one.

# shellcheck source=SCRIPTDIR/../log-record-format.sh
source "${BASH_SOURCE[0]%/*}/../log-record-format.sh"

# Writes a record of the given kind holding the given role and text pairs.
# A tab or newline inside a value becomes a space, so no value can split the
# record into extra fields or lines.
# Returns 1, writing nothing, when the values do not pair up.
#   write_log_record <kind> [<role> <text>...]
write_log_record() {

    local kind="$1"
    local value
    local record

    shift

    if (( $# % 2 != 0 )); then

        echo "write_log_record: a ${kind} record takes role and text pairs; got $# values." >&2
        return 1
    fi

    record="${LOG_RECORD_MARKER}${LOG_RECORD_SEPARATOR}${kind}"

    for value in "$@"; do
        record+="${LOG_RECORD_SEPARATOR}${value//[$'\t\n\r']/ }"
    done

    printf '%s\n' "${record}" >&2
}
