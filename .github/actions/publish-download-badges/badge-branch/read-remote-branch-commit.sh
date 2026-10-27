#!/usr/bin/env bash
# Reads which commit a branch points at on a remote. Sourced, not executed:
# defines read_remote_branch_commit.

# shellcheck source=SCRIPTDIR/../../../lib/run-git-with-token.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/run-git-with-token.sh"

# Prints the commit the branch points at on the remote, or nothing when the
# branch does not exist. ls-remote matches the pattern against the tail of each
# ref, so only the line naming the branch's full ref counts. Returns git's
# status when the remote cannot be read.
#   read_remote_branch_commit <remote url> <branch ref> <basic credential>
# shellcheck disable=SC2310 # a failed lookup is returned to the caller, not fatal here
read_remote_branch_commit() {

    local remote_url="$1"
    local branch_ref="$2"
    local basic_credential="$3"
    local listing

    listing="$(run_git_with_token "${remote_url}" "${basic_credential}" \
        ls-remote "${remote_url}" "${branch_ref}")" || return
    awk -v ref="${branch_ref}" '$2 == ref { print $1 }' <<< "${listing}"
}
