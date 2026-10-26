#!/usr/bin/env bash
# The colour escapes colors.sh writes, for the bats suites that assert a
# coloured log literally. Sourced - never run - so it carries no tests itself
# and is skipped by the recursive *.bats runner.
#
# Not readonly: bats 1.11 sources every suite of a recursive run in one shell,
# so a second suite declaring the same readonly name fails the whole run.

# shellcheck disable=SC2034 # read by the suites that source this file
YELLOW=$'\033[38;2;255;230;0m'

# shellcheck disable=SC2034 # read by the suites that source this file
GREEN=$'\033[32m'

# shellcheck disable=SC2034 # read by the suites that source this file
GREY=$'\033[90m'

# shellcheck disable=SC2034 # read by the suites that source this file
RED=$'\033[31m'

# Also the guard resolve-command-guarded-text.sh places inside a marker.
# shellcheck disable=SC2034 # read by the suites that source this file
RESET=$'\033[0m'
