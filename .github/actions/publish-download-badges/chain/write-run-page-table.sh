#!/usr/bin/env bash
# Writes a table to the run's page, unless the run is dry. Sourced, not
# executed: defines write_run_page_table.

# shellcheck source=SCRIPTDIR/../../../lib/run-stage.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/run-stage.sh"

# shellcheck source=SCRIPTDIR/is-dry-run.sh
source "${BASH_SOURCE[0]%/*}/is-dry-run.sh"

# Runs write-step-summary-table.sh through run_stage, so its log sits under a
# heading of its own like any stage's. A dry run leaves the run's page alone
# and reads nothing from stdin.
#   write_run_page_table <heading> <column name...> < lines
# shellcheck disable=SC2310 # is_dry_run's status is the answer, not a failure
write_run_page_table() {

    if is_dry_run; then
        return 0
    fi

    run_stage "${BASH_SOURCE[0]%/*}/../../../lib/write-step-summary-table.sh" "$@"
}
