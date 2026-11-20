#!/usr/bin/env bash
#
# Trims trailing spaces and tabs off every tracked file of the trimmed types,
# repo-wide.
#
# Sourced, not executed:
# defines fix_trailing_whitespace.
#
# Trailing whitespace is invisible in an editor and loud in a diff:
# it lands as a changed line that says nothing,
# which a reviewer has to read past.
# Prose is reached by no formatter in any tier,
# since every one of them reads source sets.
#
# Reads WHITESPACE_TRIMMED_TYPES,
# so a tier's types count once its declaration file is sourced.

# shellcheck source=SCRIPTDIR/list-files-with-trailing-whitespace.sh
source "${BASH_SOURCE[0]%/*}/list-files-with-trailing-whitespace.sh"

# shellcheck source=SCRIPTDIR/trim-trailing-whitespace.sh
source "${BASH_SOURCE[0]%/*}/trim-trailing-whitespace.sh"

#   fix_trailing_whitespace
fix_trailing_whitespace() {

    local offenders
    local -a offender_files

    # shellcheck disable=SC2119 # no paths on purpose: the scan covers the whole repo
    offenders="$(list_files_with_trailing_whitespace)"

    if [[ -z "${offenders}" ]]; then
        return 0
    fi

    readarray -t offender_files <<< "${offenders}"
    trim_trailing_whitespace "${offender_files[@]}"
}
