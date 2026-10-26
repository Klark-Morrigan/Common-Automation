#!/usr/bin/env bash
# Prints an error or notice record as the GitHub Actions annotation it stands
# for. Sourced, not executed: defines print_annotation_record.
#
# The annotation is plain. Whether the annotations panel renders colour is
# unknown, and an escape it showed as text would garble the one line a failed
# run is read by.

# shellcheck source=SCRIPTDIR/../../print-workflow-command.sh
source "${BASH_SOURCE[0]%/*}/../../print-workflow-command.sh"

# shellcheck source=SCRIPTDIR/../resolve-record-kind.sh
source "${BASH_SOURCE[0]%/*}/../resolve-record-kind.sh"

# shellcheck source=SCRIPTDIR/resolve-record-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-record-text.sh"

# Prints the record's text as the workflow command its kind stands for.
# Returns 1, printing nothing, for a record of any other kind.
#   print_annotation_record <error or notice record line>
print_annotation_record() {

    local command_name

    resolve_record_kind "$1"

    case "${record_kind}" in
        "${LOG_RECORD_KIND_ERROR}")  command_name="${WORKFLOW_COMMAND_ERROR}"  ;;
        "${LOG_RECORD_KIND_NOTICE}") command_name="${WORKFLOW_COMMAND_NOTICE}" ;;
        *)                           return 1                                  ;;
    esac

    resolve_record_text "$1"
    print_workflow_command "${command_name}" "${record_text}"
}
