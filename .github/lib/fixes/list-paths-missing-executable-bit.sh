#!/usr/bin/env bash
#
# Lists the tracked paths a set of git pathspecs names
# whose index mode lacks the executable bit.
#
# Sourced, not executed:
# defines list_paths_missing_executable_bit.
#
# The one rule for "missing +x",
# shared by the CI gate and both fixes so they cannot disagree.
# The index mode is what a Linux checkout gets,
# whatever the Windows working tree shows.

# Prints each path at mode 100644, repo-root-relative, one per line.
# Prints nothing when none is.
#
# Runs from the repo top:
# git reads pathspecs against the current folder,
# so a scan started in a subfolder would see only that subtree.
#
# Each line splits at the tab before its path,
# so a path holding a space comes out whole,
# and git prints the path unquoted,
# so a name outside ASCII does too.
#
# A pathspec is required:
# with none, git would list every tracked file.
#
# list_paths_missing_executable_bit <pathspec...>
#
list_paths_missing_executable_bit() {

    local repo_root
    local listed

    : "${1:?list_paths_missing_executable_bit: a pathspec is required}"

    repo_root="$(git rev-parse --show-toplevel)"

    # Captured before awk reads it, so a failed git stops the caller
    # rather than passing for an empty list.
    listed="$(cd "${repo_root}" && git -c core.quotePath=false ls-files -s -- "$@")"

    if [[ -z "${listed}" ]]; then
        return 0
    fi

    awk -F'\t' '{ split($1, meta, " ") } meta[1] == "100644" { print $2 }' <<< "${listed}"
}
