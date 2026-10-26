#!/usr/bin/env bash
# Prints an error or notice record as the GitHub Actions annotation it stands
# for. Sourced, not executed: defines print_annotation_record.
#
# The annotation is plain. Whether the annotations panel renders colour is
# unknown, and an escape it showed as text would garble the one line a failed
# run is read by.

# shellcheck source=SCRIPTDIR/resolve-record-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-record-text.sh"

# Prints the record's text as a workflow command of the given name.
#   print_annotation_record <command: error | notice> <record line>
print_annotation_record() {

    resolve_record_text "$2"
    printf '::%s::%s\n' "$1" "${record_text}"
}
