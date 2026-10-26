#!/usr/bin/env bash
# Shapes a stage's log for the GitHub Actions step log.
#
# Usage: <stage> 2>&1 >/dev/null | present-log-for-github-actions.sh
#
# Reads the stage's stderr on stdin and writes the shaped log to stdout,
# routed as present-log-records.sh says, as the terminal presenter does. What
# is this log's own:
#
# - Colour is on. The log renders ANSI colour, but its stream is never a
#   terminal, so the terminal presenter's gate would turn it off. NO_COLOR
#   still turns it off.
# - An error or notice record prints as the ::error:: or ::notice:: workflow
#   command it stands for, plain, so the run's annotations show it.
# - Every value is guarded against reading as a workflow command, since the
#   runner reads this log for them. resolve-command-guarded-text.sh says how.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The gate colors.sh reads on every call, so colour is on whatever stdout is.
# shellcheck disable=SC2034 # read by colors.sh
FORCE_COLOR=1

# Read by print_display_text, which every printed value passes through.
# shellcheck disable=SC2034 # read by print-display-text.sh
is_workflow_command_guarded=true

# shellcheck source=SCRIPTDIR/../../colors.sh
source "${script_dir}/../../colors.sh"

# shellcheck source=SCRIPTDIR/present-log-records.sh
source "${script_dir}/present-log-records.sh"

# shellcheck source=SCRIPTDIR/print-annotation-record.sh
source "${script_dir}/print-annotation-record.sh"

present_log_records print_annotation_record print_annotation_record
