#!/usr/bin/env bash
# Hands the log record format to jq. Sourced, not executed: defines
# JQ_LOG_RECORD_ARGS, which a jq call passes before its filter.
#
# A jq pass that writes records through build-log-record.jq needs the marker,
# the kinds and the roles. Passing every LOG_RECORD_* and LOG_ROLE_* constant
# under its own name keeps log-record-format.sh their one source: a jq pass
# reads $ARGS.named.LOG_ROLE_ID, never a second spelling of "id".
#
# The array's own name does not start with LOG_RECORD_, so it never lists
# itself. Not readonly: a script may source this file more than once.

# shellcheck source=SCRIPTDIR/../log-record-format.sh
source "${BASH_SOURCE[0]%/*}/../log-record-format.sh"

JQ_LOG_RECORD_ARGS=()

for log_record_constant in "${!LOG_RECORD_@}" "${!LOG_ROLE_@}"; do
    JQ_LOG_RECORD_ARGS+=(--arg "${log_record_constant}" "${!log_record_constant}")
done

unset log_record_constant
