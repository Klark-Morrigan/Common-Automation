#!/usr/bin/env bash
#
# Sets the executable bit in the index on the paths given,
# naming each one.
#
# Sourced, not executed: defines set_executable_bits.
#
# One git call for every path:
# each update-index rewrites the whole index file.

# shellcheck source=SCRIPTDIR/../colors.sh
source "${BASH_SOURCE[0]%/*}/../colors.sh"

# Each name is green, so the change stands out in a hook's output.
#
#   set_executable_bits <repo-root-relative path...>
set_executable_bits() {

    local repo_root
    local path

    repo_root="$(git rev-parse --show-toplevel)"

    for path in "$@"; do
        colorize green "fixing +x on ${path}"
        echo
    done

    (cd "${repo_root}" && git update-index --chmod=+x -- "$@")
}
