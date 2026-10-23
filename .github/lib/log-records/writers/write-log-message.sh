#!/usr/bin/env bash
# Writes a message record: one line of text, each value tagged with its role.
# Sourced, not executed: defines write_log_message.

# shellcheck source=SCRIPTDIR/write-log-record.sh
source "${BASH_SOURCE[0]%/*}/write-log-record.sh"

# Plain words take an empty role.
#   write_log_message <role> <text> [<role> <text>...]
write_log_message() {

    write_log_record "${LOG_RECORD_KIND_MESSAGE}" "$@"
}
