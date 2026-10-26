#!/usr/bin/env bash
# Writes the Actions annotations a script ends a run with. Sourced, not
# executed: defines exit_with_error, log_error, require_value and log_notice.
#
# Each annotation names the script that wrote it, as its file name without
# .sh. An action that chains several scripts shows its annotations apart from
# the step's log, so without the name an error would not say which stage
# failed. Holding the format here keeps every script's annotations alike.
#
# A stage that run_stage runs has LOG_RECORDS set to "true", and its stderr
# reaches a presenter. There an annotation is written as an error or notice
# record, so the presenter shapes it for its reader: an annotation under
# Actions, a red or plain line in a terminal. Any other script, such as a lint
# action's, writes the workflow command itself.
#
# All write to stderr, because stdout may carry the data a script hands the
# next one. The runner reads workflow commands from either stream.

# shellcheck source=SCRIPTDIR/log-records/writers/write-log-error.sh
source "${BASH_SOURCE[0]%/*}/log-records/writers/write-log-error.sh"

# shellcheck source=SCRIPTDIR/log-records/writers/write-log-notice.sh
source "${BASH_SOURCE[0]%/*}/log-records/writers/write-log-notice.sh"

# Prints an error annotation, then exits 1.
#   exit_with_error <message...>
exit_with_error() {

    log_error "$@"
    exit 1
}

# Prints an error annotation, for a caller that ends the script with an exit
# status of its own.
#   log_error <message...>
log_error() {

    local script_file_name="${0##*/}"
    local annotation_text="${script_file_name%.sh}: $*"

    if [[ "${LOG_RECORDS:-}" == "true" ]]; then

        write_log_error "${LOG_ROLE_PLAIN}" "${annotation_text}"
        return 0
    fi

    echo "::error::${annotation_text}" >&2
}

# Fails the run through exit_with_error when a required input is empty, so a
# missing input is annotated like any other failure. ${name:?} would print a
# bare line instead.
#   require_value <input name> <value>
require_value() {

    if [[ -z "$2" ]]; then

        exit_with_error "$1 is required."
    fi
}

# Prints a notice annotation, for a run's outcome.
#   log_notice <message...>
log_notice() {

    local script_file_name="${0##*/}"
    local annotation_text="${script_file_name%.sh}: $*"

    if [[ "${LOG_RECORDS:-}" == "true" ]]; then

        write_log_notice "${LOG_ROLE_PLAIN}" "${annotation_text}"
        return 0
    fi

    echo "::notice::${annotation_text}" >&2
}
