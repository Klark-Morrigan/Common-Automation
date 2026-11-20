#!/usr/bin/env bash
#
# Lists the tracked files of the trimmed types
# that have a line ending in whitespace.
#
# Sourced, not executed:
# defines list_files_with_trailing_whitespace.
#
# No paths scans the whole repo.
# Paths narrow the scan to those,
# and are still held to the trimmed types,
# so a caller handing over a mixed list cannot widen the rule.

# shellcheck source=SCRIPTDIR/trailing-whitespace-pattern.sh
source "${BASH_SOURCE[0]%/*}/trailing-whitespace-pattern.sh"

# shellcheck source=SCRIPTDIR/trimmed-file-types.sh
source "${BASH_SOURCE[0]%/*}/trimmed-file-types.sh"

# Prints each offender, repo-root-relative, one per line.
#
# One git grep for every file.
# It reads tracked files only,
# so a build folder or an untracked scratch file is never rewritten,
# and -I skips a file that is binary despite its name.
# Basic regular expressions and no colour are forced,
# whatever the user's grep settings say.
#
# A path goes to git as a literal pathspec,
# so a [ or * in its name cannot match another file.
# Names print unquoted,
# so a name outside ASCII reaches the trim as the file it names.
#
#   list_files_with_trailing_whitespace [repo-root-relative path...]
list_files_with_trailing_whitespace() {

    local repo_root
    local path
    local file_type
    local listed
    local grep_status=0
    local -a pathspecs=()

    repo_root="$(git rev-parse --show-toplevel)"

    if (( $# == 0 )); then
        pathspecs=("${WHITESPACE_TRIMMED_TYPES[@]}")
    fi

    for path in "$@"; do
        for file_type in "${WHITESPACE_TRIMMED_TYPES[@]}"; do
            # shellcheck disable=SC2053 # the right side is a pattern on purpose
            if [[ "${path}" == ${file_type} ]]; then
                pathspecs+=(":(literal)${path}")
                break
            fi
        done
    done

    if (( ${#pathspecs[@]} == 0 )); then
        return 0
    fi

    # git grep exits 1 when nothing matches, which is the common answer here.
    listed="$(cd "${repo_root}" \
        && git -c core.quotePath=false grep -l -I -G --no-color \
            -e "${TRAILING_WHITESPACE_PATTERN}" -- "${pathspecs[@]}")" \
        || grep_status=$?

    if (( grep_status > 1 )); then
        return "${grep_status}"
    fi

    if [[ -n "${listed}" ]]; then
        printf '%s\n' "${listed}"
    fi
}
