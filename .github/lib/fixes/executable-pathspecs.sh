#!/usr/bin/env bash
#
# shellcheck disable=SC2034 # every variable here is read by the files that source this
#
# The paths every repo in the family keeps executable, as git pathspecs.
#
# Sourced, not executed.
#
# Files written on Windows land in git without +x.
# A Linux runner then cannot run a script directly,
# and git skips a hook outright,
# so both kinds are declared here, once,
# for the hook, the manual runner and setup-hooks.sh alike.
#
# A tier with executables of its own appends to EXECUTABLE_PATHSPECS
# in its declaration file, such as Common-Java's gradlew.

# Git hooks carry no extension.
# A dotfile beside them, such as .gitignore, is never a hook,
# so it stays out.
GIT_HOOK_PATHSPECS=('.githooks/*' ':(exclude).githooks/.*')

# Declared only when unset,
# so sourcing this again after a tier widened the set
# cannot drop the tier's paths.
if [[ ! -v EXECUTABLE_PATHSPECS ]]; then
    EXECUTABLE_PATHSPECS=('*.sh' "${GIT_HOOK_PATHSPECS[@]}")
fi
