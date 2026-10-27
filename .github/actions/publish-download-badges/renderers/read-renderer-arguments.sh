#!/usr/bin/env bash
# Reads what every renderer starts from: its arguments, then the summary on
# stdin. Sourced, not executed: defines read_renderer_arguments.
#
# Every renderer takes the same arguments and reads the same summary, so each
# checks them here, the same way, before it writes anything.

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/../summaries/read-release-summary.sh
source "${BASH_SOURCE[0]%/*}/../summaries/read-release-summary.sh"

# Leaves the label in RENDERER_LABEL and the output directory in
# RENDERER_OUTPUT_DIR, then reads the summary through read_release_summary.
# Fails through exit_with_error when either argument is empty, the directory
# does not exist or the summary is malformed, so a renderer writes nothing
# from a bad call.
#   read_renderer_arguments <label> <output-dir> < summary
read_renderer_arguments() {

    RENDERER_LABEL="${1:-}"
    RENDERER_OUTPUT_DIR="${2:-}"

    require_value "label" "${RENDERER_LABEL}"
    require_value "output directory" "${RENDERER_OUTPUT_DIR}"

    if [[ ! -d "${RENDERER_OUTPUT_DIR}" ]]; then
        exit_with_error "output directory '${RENDERER_OUTPUT_DIR}' does not exist."
    fi

    read_release_summary
}
