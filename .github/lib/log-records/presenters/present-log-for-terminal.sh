#!/usr/bin/env bash
# Shapes a stage's log for a person at a terminal.
#
# Usage: <stage> 2>&1 >/dev/null | present-log-for-terminal.sh
#
# Reads the stage's stderr on stdin and writes the shaped log to stdout. A
# stage writes its log as plain records, through ../writers/, so it never
# decides how its log looks; ../log-record-format.sh states the format, and
# present-log-records.sh how each line is routed.
#
# What is the terminal's own:
# - Colour goes through colors.sh, gated on this script's stdout: on in a
#   terminal, off when piped or captured, and NO_COLOR and FORCE_COLOR
#   override it as colors.sh documents.
# - An error record prints as one red line, and a notice record as a message.
#   Each names the script that wrote it, as its annotation would under GitHub
#   Actions.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourced first, so the colour gate reads this script's stdout.
# shellcheck source=SCRIPTDIR/../../colors.sh
source "${script_dir}/../../colors.sh"

# shellcheck source=SCRIPTDIR/present-log-records.sh
source "${script_dir}/present-log-records.sh"

# shellcheck source=SCRIPTDIR/print-error-record.sh
source "${script_dir}/print-error-record.sh"

present_log_records print_error_record print_message_record
