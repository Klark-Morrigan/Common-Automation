#!/usr/bin/env bats
# Unit tests for split-stage-exports.sh.
# Run with: bats .github/lib/split-stage-exports.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/split-stage-exports.sh
source "${BATS_TEST_DIRNAME}/split-stage-exports.sh"

@test "takes each --export name, then the stage and its arguments" {

    split_stage_exports --export GH_TOKEN --export OTHER stage.sh "a b" c

    [ "${stage_exports[*]}" = "GH_TOKEN OTHER" ]
    [ "${#stage_command[@]}" -eq 3 ]
    [ "${stage_command[0]}" = "stage.sh" ]
    [ "${stage_command[1]}" = "a b" ]
}

@test "takes no name from a call without flags" {

    split_stage_exports stage.sh --export GH_TOKEN

    [ "${#stage_exports[@]}" -eq 0 ]
    [ "${stage_command[*]}" = "stage.sh --export GH_TOKEN" ]
}

@test "fails, saying why, when --export has no name" {

    run --separate-stderr split_stage_exports --export

    [ "${status}" -eq 1 ]
    [ "${stderr}" = "split_stage_exports: --export needs a variable name." ]
}

@test "fails, saying why, when no stage follows the flags" {

    run --separate-stderr split_stage_exports --export GH_TOKEN

    [ "${status}" -eq 1 ]
    [ "${stderr}" = "split_stage_exports: no stage follows the flags." ]
}
