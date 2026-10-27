#!/usr/bin/env bash
# The environment variable each of action.yml's inputs reaches the scripts as.
# Sourced, not executed: defines ACTION_INPUT_VARIABLES.
#
# action.yml's env: block cannot read this file, so the two are kept in step by
# hand. The dry run builds its flags from it, so a new input reaches the dry
# run without a second list to keep in step.

# Each input and its variable, as "<input>=<variable>".
# shellcheck disable=SC2034 # read by the files that source this one
ACTION_INPUT_VARIABLES=(
    asset-name-regex=ASSET_NAME_REGEX
    branch=BADGE_BRANCH
    default-locale=DEFAULT_LOCALE
    label=BADGE_LABEL
    token=GH_TOKEN
)
