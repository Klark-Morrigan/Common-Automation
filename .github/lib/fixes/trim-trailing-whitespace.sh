#!/usr/bin/env bash
#
# Trims trailing whitespace off the files given, naming each one.
#
# Sourced, not executed:
# defines trim_trailing_whitespace.
#
# One sed for every file.
# -b reads each file as bytes:
# Git Bash's sed reads in text mode and drops each line's CR
# before the pattern sees it, which would turn a CRLF file into LF.
# A sed with no text mode, as on Linux, ignores -b.

# shellcheck source=SCRIPTDIR/../colors.sh
source "${BASH_SOURCE[0]%/*}/../colors.sh"

# shellcheck source=SCRIPTDIR/trailing-whitespace-pattern.sh
source "${BASH_SOURCE[0]%/*}/trailing-whitespace-pattern.sh"

# Each name is green, so the rewrite stands out in a hook's output.
#
# trim_trailing_whitespace <repo-root-relative file...>
trim_trailing_whitespace() {

    local repo_root
    local file

    repo_root="$(git rev-parse --show-toplevel)"

    for file in "$@"; do
        colorize green "trimming trailing whitespace in ${file}"
        echo
    done

    (cd "${repo_root}" && sed -b -i "s/${TRAILING_WHITESPACE_PATTERN}/\\1/" -- "$@")
}
