#!/usr/bin/env bash
# Loads every log record writer, so a stage sources one file rather than one
# per writer. Sourced, not executed: defines no function of its own, and each
# writer keeps its own file.

# shellcheck source=SCRIPTDIR/write-log-message.sh
source "${BASH_SOURCE[0]%/*}/write-log-message.sh"

# shellcheck source=SCRIPTDIR/write-log-row.sh
source "${BASH_SOURCE[0]%/*}/write-log-row.sh"

# shellcheck source=SCRIPTDIR/write-log-table.sh
source "${BASH_SOURCE[0]%/*}/write-log-table.sh"

# shellcheck source=SCRIPTDIR/write-log-table-end.sh
source "${BASH_SOURCE[0]%/*}/write-log-table-end.sh"

# shellcheck source=SCRIPTDIR/write-log-total.sh
source "${BASH_SOURCE[0]%/*}/write-log-total.sh"
