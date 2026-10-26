#!/usr/bin/env bash
# Writes an annotation that names the running script. Sourced, not executed:
# defines write_script_annotation, the one body behind log_error and
# log_notice in workflow-commands.sh.
#
# A stage that run_stage runs has LOG_RECORDS set to "true", and its stderr
# reaches a presenter. There the annotation is written as a record, so the
# presenter shapes it for its reader. Any other script writes the workflow
# command itself.

# shellcheck source=SCRIPTDIR/log-records/log-record-format.sh
source "${BASH_SOURCE[0]%/*}/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/print-workflow-command.sh
source "${BASH_SOURCE[0]%/*}/print-workflow-command.sh"

# Writes "<script>: <message>" to stderr, the script named by its file name
# without .sh, through the record writer or as the workflow command.
#   write_script_annotation <workflow command name> <record writer function> <message...>
write_script_annotation() {

    local command_name="$1"
    local record_writer="$2"
    local script_file_name="${0##*/}"
    local annotation_text

    shift 2

    annotation_text="${script_file_name%.sh}: $*"

    if [[ "${LOG_RECORDS:-}" == "true" ]]; then
        "${record_writer}" "${LOG_ROLE_PLAIN}" "${annotation_text}"
        return 0
    fi

    print_workflow_command "${command_name}" "${annotation_text}" >&2
}
