#!/usr/bin/env bash
# Pushes a rendered commit over a branch, leased on the commit the run read.
# Sourced, not executed: defines push_rendered_commit.

# The roles its message names.
# shellcheck source=SCRIPTDIR/../../../lib/log-records/log-record-format.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../../lib/log-records/writers/write-log-message.sh
source "${BASH_SOURCE[0]%/*}/../../../lib/log-records/writers/write-log-message.sh"

# shellcheck source=SCRIPTDIR/read-remote-branch-commit.sh
source "${BASH_SOURCE[0]%/*}/read-remote-branch-commit.sh"

# shellcheck source=SCRIPTDIR/run-git-with-token.sh
source "${BASH_SOURCE[0]%/*}/run-git-with-token.sh"

# Pushes the rendered commit to the branch, leased on the published commit. An
# empty published commit means the branch must not exist yet.
#
# An attempt can land and still report a failure, such as a connection dropped
# before the answer. Its retry would then meet a branch that moved, and the
# lease would refuse it. So a failed attempt reads the branch back: holding the
# rendered commit, it landed. Anything else keeps the push's own failure, for a
# retry to classify.
#   push_rendered_commit <remote url> <branch ref> <published commit> <rendered commit> <basic credential>
# shellcheck disable=SC2310 # each failure is read and decided on here, not fatal
push_rendered_commit() {

    local remote_url="$1"
    local branch_ref="$2"
    local published_commit="$3"
    local rendered_commit="$4"
    local basic_credential="$5"
    local push_status=0
    local branch_commit=""

    run_git_with_token "${remote_url}" "${basic_credential}" push -q \
        --force-with-lease="${branch_ref}:${published_commit}" \
        "${remote_url}" "${rendered_commit}:${branch_ref}" || push_status=$?

    if (( push_status == 0 )); then
        return 0
    fi

    # A failed read leaves the push's own failure standing.
    branch_commit="$(read_remote_branch_commit "${remote_url}" "${branch_ref}" "${basic_credential}")" || true

    if [[ "${branch_commit}" == "${rendered_commit}" ]]; then

        write_log_message \
            "${LOG_ROLE_PLAIN}" "The push reported a failure, but " \
            "${LOG_ROLE_ID}" "${branch_ref#refs/heads/}" \
            "${LOG_ROLE_PLAIN}" " already holds " \
            "${LOG_ROLE_ID}" "${rendered_commit}" \
            "${LOG_ROLE_PLAIN}" "."
        return 0
    fi

    return "${push_status}"
}
