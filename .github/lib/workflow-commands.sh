#!/usr/bin/env bash
# Writes the GitHub Actions annotations a script ends a run with. Sourced, not
# executed: defines exit_with_error, log_error, require_value and log_notice.
#
# Each annotation names the script that wrote it, as its file name without
# .sh. An action that chains several scripts shows its annotations apart from
# the step's log, so without the name an error would not say which stage
# failed. write-script-annotation.sh holds the one body they share.
#
# All write to stderr, because stdout may carry the data a script hands the
# next one. The runner reads workflow commands from either stream.

# shellcheck source=SCRIPTDIR/log-records/writers/write-log-error.sh
source "${BASH_SOURCE[0]%/*}/log-records/writers/write-log-error.sh"

# shellcheck source=SCRIPTDIR/log-records/writers/write-log-notice.sh
source "${BASH_SOURCE[0]%/*}/log-records/writers/write-log-notice.sh"

# shellcheck source=SCRIPTDIR/write-script-annotation.sh
source "${BASH_SOURCE[0]%/*}/write-script-annotation.sh"

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

    write_script_annotation "${WORKFLOW_COMMAND_ERROR}" write_log_error "$@"
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

    write_script_annotation "${WORKFLOW_COMMAND_NOTICE}" write_log_notice "$@"
}
