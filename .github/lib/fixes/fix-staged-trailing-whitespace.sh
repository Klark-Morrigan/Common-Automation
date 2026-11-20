#!/usr/bin/env bash
#
# The pre-commit fix for whitespace:
# trims the staged files of the trimmed types and re-stages them.
#
# Sourced, not executed:
# defines fix_staged_trailing_whitespace.
#
# A file with unstaged changes beside its staged ones is named and left alone.
# This fix rewrites content, unlike the +x one,
# so re-adding such a file would sweep the author's unstaged hunks
# into the commit.

# shellcheck source=SCRIPTDIR/list-files-with-trailing-whitespace.sh
source "${BASH_SOURCE[0]%/*}/list-files-with-trailing-whitespace.sh"

# shellcheck source=SCRIPTDIR/list-staged-paths.sh
source "${BASH_SOURCE[0]%/*}/list-staged-paths.sh"

# shellcheck source=SCRIPTDIR/trim-trailing-whitespace.sh
source "${BASH_SOURCE[0]%/*}/trim-trailing-whitespace.sh"

# Paths go to git as literal pathspecs read from the repo top,
# so neither a [ in a name nor the folder git runs in
# can point it at another file.
#
#   fix_staged_trailing_whitespace
fix_staged_trailing_whitespace() {

    local staged offenders unstaged file
    local -A is_unstaged=()
    local -a staged_paths offender_files
    local -a trimmable=()

    staged="$(list_staged_paths)"

    if [[ -z "${staged}" ]]; then
        return 0
    fi

    readarray -t staged_paths <<< "${staged}"
    offenders="$(list_files_with_trailing_whitespace "${staged_paths[@]}")"

    if [[ -z "${offenders}" ]]; then
        return 0
    fi

    readarray -t offender_files <<< "${offenders}"
    unstaged="$(git -c core.quotePath=false diff --name-only -- "${offender_files[@]/#/:(top,literal)}")"

    while IFS= read -r file; do
        if [[ -n "${file}" ]]; then
            is_unstaged["${file}"]=1
        fi
    done <<< "${unstaged}"

    for file in "${offender_files[@]}"; do
        if [[ -n "${is_unstaged["${file}"]:-}" ]]; then
            echo "trailing whitespace left in ${file}: it has unstaged changes, so it was not re-staged"
        else
            trimmable+=("${file}")
        fi
    done

    if (( ${#trimmable[@]} == 0 )); then
        return 0
    fi

    trim_trailing_whitespace "${trimmable[@]}"
    git add -- "${trimmable[@]/#/:(top,literal)}"
}
