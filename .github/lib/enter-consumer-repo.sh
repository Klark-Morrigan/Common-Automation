#!/usr/bin/env bash
#
# Moves into the repo CONSUMER_REPO_PATH names,
# for a lint action's helper that checks the current folder.
#
# Sourced, not executed:
# defines enter_consumer_repo.
#
# The scripts/ runners already take the consumer repo from this variable.
# The lint helpers read the current folder instead,
# so a caller outside the repo had to cd first,
# a compound command no single allow rule matches.
#
# CI sets nothing and runs from the checkout,
# which stays the default.

# Moves into CONSUMER_REPO_PATH when it is set.
#
# Returns 1 with an ::error:: line when it names no folder,
# rather than linting the wrong one.
#
enter_consumer_repo() {

    if [[ -z "${CONSUMER_REPO_PATH:-}" ]]; then
        return 0
    fi

    if ! cd "${CONSUMER_REPO_PATH}" 2>/dev/null; then

        echo "::error::CONSUMER_REPO_PATH names ${CONSUMER_REPO_PATH}, which is not a folder."
        return 1
    fi
}
