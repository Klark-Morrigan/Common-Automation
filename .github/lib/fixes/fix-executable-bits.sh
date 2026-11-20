#!/usr/bin/env bash
#
# Sets +x on every tracked path the executable set names that lacks it,
# repo-wide.
#
# Sourced, not executed:
# defines fix_executable_bits.
#
# The manual heal for files that reached the index without +x
# before the hook was wired up,
# or through a commit that skips hooks.
#
# Reads EXECUTABLE_PATHSPECS,
# so a tier's paths count once its declaration file is sourced.

# shellcheck source=SCRIPTDIR/executable-pathspecs.sh
source "${BASH_SOURCE[0]%/*}/executable-pathspecs.sh"

# shellcheck source=SCRIPTDIR/list-paths-missing-executable-bit.sh
source "${BASH_SOURCE[0]%/*}/list-paths-missing-executable-bit.sh"

# shellcheck source=SCRIPTDIR/set-executable-bits.sh
source "${BASH_SOURCE[0]%/*}/set-executable-bits.sh"

#   fix_executable_bits
fix_executable_bits() {

    local missing
    local -a missing_paths

    missing="$(list_paths_missing_executable_bit "${EXECUTABLE_PATHSPECS[@]}")"

    if [[ -z "${missing}" ]]; then
        return 0
    fi

    readarray -t missing_paths <<< "${missing}"
    set_executable_bits "${missing_paths[@]}"
}
