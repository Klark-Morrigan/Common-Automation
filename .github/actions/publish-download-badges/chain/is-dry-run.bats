#!/usr/bin/env bats
# Unit tests for is-dry-run.sh.
# Run with: bats .github/actions/publish-download-badges/chain/is-dry-run.bats

# run ! arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/is-dry-run.sh
source "${BATS_TEST_DIRNAME}/is-dry-run.sh"

@test "succeeds when BADGE_DRY_RUN is true" {

    BADGE_DRY_RUN=true run is_dry_run

    [ "${status}" -eq 0 ]
}

@test "fails when BADGE_DRY_RUN is unset" {

    unset BADGE_DRY_RUN

    run ! is_dry_run
}

# Only the exact word turns publishing off, so a typo publishes rather than
# silently skipping a scheduled run's publish.
@test "fails when BADGE_DRY_RUN holds anything but true" {

    BADGE_DRY_RUN=yes run ! is_dry_run
}
