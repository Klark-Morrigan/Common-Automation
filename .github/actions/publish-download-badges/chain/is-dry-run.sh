#!/usr/bin/env bash
# Tells whether the chain runs dry. Sourced, not executed: defines is_dry_run.
#
# A dry run reads and renders, but writes no table and publishes nothing. The
# chaining script and the functions it calls all ask here, so BADGE_DRY_RUN is
# read one way.

# Succeeds when BADGE_DRY_RUN is "true". Any other value, or none, is a run
# that publishes.
#   is_dry_run
is_dry_run() {

    [[ "${BADGE_DRY_RUN:-}" == "true" ]]
}
