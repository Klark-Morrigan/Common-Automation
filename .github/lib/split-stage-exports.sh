#!/usr/bin/env bash
# Reads a stage call's leading --export flags. Sourced, not executed: defines
# split_stage_exports.
#
# A chain holds a secret such as a token as a plain shell variable, exported to
# nothing. Each stage that needs it names it with --export, and only that
# stage's process gets it: never its presenter, never the stages beside it.
# Names travel, never values, so a secret is never an argument.

# Leaves the names given with --export in stage_exports, and the stage and its
# arguments in stage_command. Returns 1, saying why, when --export has no name
# or no stage follows the flags.
#   split_stage_exports [--export <variable name>]... <stage> [arguments...]
# shellcheck disable=SC2034 # stage_exports and stage_command are the result, read by the caller
split_stage_exports() {

    stage_exports=()

    while [[ "${1:-}" == "--export" ]]; do

        if (( $# < 2 )); then

            echo "split_stage_exports: --export needs a variable name." >&2
            return 1
        fi

        stage_exports+=("$2")
        shift 2
    done

    if (( $# == 0 )); then

        echo "split_stage_exports: no stage follows the flags." >&2
        return 1
    fi

    stage_command=("$@")
}
