#!/usr/bin/env bash
# Logs what a publish does to each rendered file. Sourced, not executed:
# defines log_rendered_file_changes.

# The roles its table names.
# shellcheck source=SCRIPTDIR/../../../lib/log-records/log-record-format.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../../lib/log-records/writers/write-log-records.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/log-records/writers/write-log-records.sh"

# Logs a table of each rendered file: added, changed or unchanged on the
# branch. Added and changed are what this run publishes, so they read as
# current.
#   log_rendered_file_changes <diff-tree --name-status lines> <rendered file names>
log_rendered_file_changes() {

    local file_changes="$1"
    local rendered_files="$2"
    local change file_name
    local -A change_by_file=()

    # An unchanged run's empty list still reads as one blank line.
    while IFS=$'\t' read -r change file_name; do

        if [[ -n "${file_name}" ]]; then

            change_by_file["${file_name}"]="${change}"
        fi
    done <<< "${file_changes}"

    write_log_table "File" "Change"

    while IFS= read -r file_name; do

        case "${change_by_file[${file_name}]:-}" in
            "") write_log_row "${LOG_ROLE_PLAIN}" "${file_name}" "${LOG_ROLE_PLAIN}" "unchanged" ;;
            A) write_log_row "${LOG_ROLE_PLAIN}" "${file_name}" "${LOG_ROLE_CURRENT}" "added" ;;
            *) write_log_row "${LOG_ROLE_PLAIN}" "${file_name}" "${LOG_ROLE_CURRENT}" "changed" ;;
        esac
    done <<< "${rendered_files}"

    write_log_table_end
}
