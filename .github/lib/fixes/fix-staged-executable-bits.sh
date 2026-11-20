#!/usr/bin/env bash
#
# The pre-commit fix for +x:
# sets it on the staged paths the executable set names that lack it.
#
# Sourced, not executed:
# defines fix_staged_executable_bits.
#
# Staged paths only,
# so the hook never stages a mode change on a file the author left out.
#
# Matched against EXECUTABLE_PATHSPECS by git itself,
# so the hook and the manual runner read one rule,
# and a tier's paths count once its declaration file is sourced.

# shellcheck source=SCRIPTDIR/executable-pathspecs.sh
source "${BASH_SOURCE[0]%/*}/executable-pathspecs.sh"

# shellcheck source=SCRIPTDIR/list-paths-missing-executable-bit.sh
source "${BASH_SOURCE[0]%/*}/list-paths-missing-executable-bit.sh"

# shellcheck source=SCRIPTDIR/list-staged-paths.sh
source "${BASH_SOURCE[0]%/*}/list-staged-paths.sh"

# shellcheck source=SCRIPTDIR/set-executable-bits.sh
source "${BASH_SOURCE[0]%/*}/set-executable-bits.sh"

#   fix_staged_executable_bits
fix_staged_executable_bits() {

    local staged missing path
    local -A is_staged=()
    local -a staged_missing=()

    staged="$(list_staged_paths)"

    if [[ -z "${staged}" ]]; then
        return 0
    fi

    missing="$(list_paths_missing_executable_bit "${EXECUTABLE_PATHSPECS[@]}")"

    if [[ -z "${missing}" ]]; then
        return 0
    fi

    while IFS= read -r path; do
        is_staged["${path}"]=1
    done <<< "${staged}"

    while IFS= read -r path; do
        if [[ -n "${is_staged["${path}"]:-}" ]]; then
            staged_missing+=("${path}")
        fi
    done <<< "${missing}"

    if (( ${#staged_missing[@]} == 0 )); then
        return 0
    fi

    set_executable_bits "${staged_missing[@]}"
}
