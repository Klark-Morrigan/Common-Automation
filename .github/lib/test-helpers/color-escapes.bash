#!/usr/bin/env bash
# The colour escapes colors.sh writes, for the bats suites that assert a
# coloured log literally. Sourced - never run - so it carries no tests itself,
# and it is not a *.bats file, so no bats run takes it for a suite.

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
