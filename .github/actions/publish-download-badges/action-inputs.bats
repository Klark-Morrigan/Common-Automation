#!/usr/bin/env bats
# Contract tests between action.yml's inputs and the environment variables its
# step hands the scripts.
# Run with: bats .github/actions/publish-download-badges/action-inputs.bats
#
# Every script suite sets its environment variables itself, so a mistyped
# variable name in action.yml's env: block passes all of them. The action
# would then hand the script an empty value, which the script reads as unset:
# a misspelt DEFAULT_LOCALE turns every unlocalised zip into a count under no
# locale, and no run fails.

ACTION_FILE="${BATS_TEST_DIRNAME}/action.yml"

# shellcheck source=SCRIPTDIR/action-input-variables.sh
source "${BATS_TEST_DIRNAME}/action-input-variables.sh"

# Echoes the inputs action.yml declares, one per line, sorted: the keys
# indented one level under `inputs:`, up to the next top-level key.
read_declared_inputs() {

    awk '/^inputs:/ { inside = 1; next }
         /^[^[:space:]]/ { inside = 0 }
         inside && /^  [a-z][a-z0-9-]*:$/ { sub(/^  /, ""); sub(/:$/, ""); print }' \
        "${ACTION_FILE}" | sort
}

@test "the step passes each input as its variable" {

    local pair input variable

    for pair in "${ACTION_INPUT_VARIABLES[@]}"; do

        input="${pair%%=*}"
        variable="${pair#*=}"

        grep -qE "^[[:space:]]+${variable}: \\$\\{\\{ inputs\\.${input} \\}\\}$" "${ACTION_FILE}" || {
            echo "action.yml does not pass input '${input}' as ${variable}" >&2
            return 1
        }
    done
}

@test "the input list names every input action.yml declares" {

    # Without this the test above passes by omission: a new input arrives and
    # nothing checks how it reaches the scripts.
    local declared covered

    declared="$(read_declared_inputs)"
    covered="$(printf '%s\n' "${ACTION_INPUT_VARIABLES[@]%%=*}" | sort)"

    # A broken extraction would otherwise compare an empty list and fail
    # without saying why.
    [ -n "${declared}" ]
    [ "${declared}" = "${covered}" ]
}
