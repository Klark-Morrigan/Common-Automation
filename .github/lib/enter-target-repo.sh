#!/usr/bin/env bash
#
# Moves into the repo COMMON_AUTOMATION_TARGET_REPO names,
# for a lint action's helper that checks the current folder.
#
# Sourced, not executed:
# defines enter_target_repo.
#
# The scripts/ runners already take the target repo from this variable.
# The lint helpers read the current folder instead,
# so a caller outside the repo had to cd first,
# a compound command no single allow rule matches.
#
# CI sets nothing and runs from the checkout,
# which stays the default.

# Moves into COMMON_AUTOMATION_TARGET_REPO when it is set.
#
# Returns 1 with an ::error:: line when it names no folder,
# rather than linting the wrong one.
#
enter_target_repo() {

    if [[ -z "${COMMON_AUTOMATION_TARGET_REPO:-}" ]]; then
        return 0
    fi

    if ! cd "${COMMON_AUTOMATION_TARGET_REPO}" 2>/dev/null; then

        echo "::error::COMMON_AUTOMATION_TARGET_REPO names ${COMMON_AUTOMATION_TARGET_REPO}, which is not a folder."
        return 1
    fi
}
