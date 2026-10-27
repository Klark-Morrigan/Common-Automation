#!/usr/bin/env bash
# Publishes a directory of rendered badge files as the whole content of one
# branch, so shields can fetch each file from raw.githubusercontent.com.
#
# Usage: publish-badge-branch.sh <source-dir> <branch>
#
# Inputs read from the environment:
#   GITHUB_REPOSITORY  owner/name of the repository published to.
#   GH_TOKEN           token the lookup and push authenticate with. Pushing
#                      needs contents: write on GITHUB_REPOSITORY. Cleared
#                      once read, so no process the script starts inherits it.
#   RETRY_*            optional retry tuning, read by retry.sh's
#                      retry_command. Default classifiers:
#                      RETRY_CLASSIFIER_SET_HTTP.
#
# The branch holds one commit whose tree is exactly <source-dir>. The branch is
# created on the first run, so it needs no setup by hand. A run whose files
# match that tree leaves the branch alone, so a schedule does not commit
# figures that have not moved. A run whose files differ replaces the commit.
#
# A run never withdraws a file the branch already serves. Each file backs a
# public badge, and a badge whose file is gone renders as an error. A run
# whose <source-dir> lacks a published file - a renderer that wrote nothing, a
# figure renamed - is refused, and the branch keeps every last good figure.
# Retiring a figure is a deliberate act by hand: delete its file from the
# branch once nothing links to it, and later runs no longer hold it.
#
# Replacing means a force-push, which is safe only because the branch is
# generated output: nobody branches from it, and its history would hold
# nothing but old figures, one commit per change for as long as the schedule
# runs. The push leases on the commit this run read, so figures another run
# published in the meantime are refused rather than overwritten unseen. It
# names the branch's full ref, never a bare `git push`, so it cannot reach any
# other branch.
#
# Works in a temporary repository, never the caller's checkout: the checkout
# is left alone, and a caller with none can publish too. The token travels in
# an HTTP header that only the git calls reaching GitHub get, as
# run-git-with-token.sh says.
#
# Logs to stderr, as log records, whether it found the branch, a table of each
# file it adds, changes or leaves unchanged, and the commit it pushes.
#
# Exits non-zero, publishing nothing, when <source-dir> is missing, holds no
# file or lacks a published one, <branch> is not a valid branch name, or the
# lookup or push fails.

set -euo pipefail

readonly GITHUB_HOST="github.com"

# The identity GitHub shows for commits a workflow's own token makes.
readonly COMMITTER_NAME="github-actions[bot]"
readonly COMMITTER_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
readonly COMMIT_MESSAGE="Publish badge figures"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../lib/create-masked-basic-credential.sh
source "${repo_root}/.github/lib/create-masked-basic-credential.sh"

# The roles its messages name.
# shellcheck source=SCRIPTDIR/../../lib/log-records/log-record-format.sh
source "${repo_root}/.github/lib/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../lib/log-records/writers/write-log-message.sh
source "${repo_root}/.github/lib/log-records/writers/write-log-message.sh"

# shellcheck source=SCRIPTDIR/../../lib/retry.sh
source "${repo_root}/.github/lib/retry.sh"

# shellcheck source=SCRIPTDIR/../../lib/run-git-with-token.sh
source "${repo_root}/.github/lib/run-git-with-token.sh"

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/badge-branch/log-rendered-file-changes.sh
source "${script_dir}/badge-branch/log-rendered-file-changes.sh"

# shellcheck source=SCRIPTDIR/badge-branch/push-rendered-commit.sh
source "${script_dir}/badge-branch/push-rendered-commit.sh"

# shellcheck source=SCRIPTDIR/badge-branch/read-remote-branch-commit.sh
source "${script_dir}/badge-branch/read-remote-branch-commit.sh"

source_dir="${1:-}"
branch="${2:-}"
repository="${GITHUB_REPOSITORY:-}"
token="${GH_TOKEN:-}"

require_value "source directory" "${source_dir}"
require_value "branch" "${branch}"
require_value GITHUB_REPOSITORY "${repository}"
require_value GH_TOKEN "${token}"

# Read once, then cleared, so no process this script starts inherits it. Only
# the git calls reaching GitHub get the token, as a header.
unset GH_TOKEN

if [[ ! -d "${source_dir}" ]]; then

    exit_with_error "source directory '${source_dir}' does not exist."
fi

# Checked on its own for the first run, which has no published file to
# withdraw: it would otherwise create an empty branch. Folders alone do not
# count: git stages files only.
first_source_file="$(find "${source_dir}" -type f -print -quit)"

if [[ -z "${first_source_file}" ]]; then

    exit_with_error "source directory '${source_dir}' holds no file."
fi

if ! git check-ref-format --branch "${branch}" > /dev/null 2>&1; then

    exit_with_error "'${branch}' is not a valid branch name."
fi

# Absolute, because git reads it as a work tree from another directory.
source_dir="$(cd "${source_dir}" && pwd)"

branch_ref="refs/heads/${branch}"
remote_url="https://${GITHUB_HOST}/${repository}.git"

create_masked_basic_credential "${token}"

# A rejected token fails the call rather than leaving it waiting on a password
# prompt.
export GIT_TERMINAL_PROMPT=0
export RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_HTTP}}"

work_repo="$(mktemp -d)"
trap 'rm -rf "${work_repo}"' EXIT

git init -q --bare "${work_repo}"

# Every git call from here runs against the temporary repository.
export GIT_DIR="${work_repo}"

# shellcheck disable=SC2311 # retry_or_exit exits on its own failure
published_commit="$(retry_or_exit "look up ${branch} on ${repository}" \
    read_remote_branch_commit "${remote_url}" "${branch_ref}" "${basic_credential}")"

if [[ -n "${published_commit}" ]]; then

    write_log_message \
        "${LOG_ROLE_PLAIN}" "Found " \
        "${LOG_ROLE_ID}" "${branch}" \
        "${LOG_ROLE_PLAIN}" " on " \
        "${LOG_ROLE_ID}" "${repository}" \
        "${LOG_ROLE_PLAIN}" " at " \
        "${LOG_ROLE_ID}" "${published_commit}" \
        "${LOG_ROLE_PLAIN}" "."

    retry_or_exit "fetch ${branch} from ${repository}" \
        run_git_with_token "${remote_url}" "${basic_credential}" \
        fetch -q --depth 1 "${remote_url}" "${published_commit}"

    published_tree="$(git rev-parse "${published_commit}^{tree}")"
else

    write_log_message \
        "${LOG_ROLE_ID}" "${branch}" \
        "${LOG_ROLE_PLAIN}" " does not exist on " \
        "${LOG_ROLE_ID}" "${repository}" \
        "${LOG_ROLE_PLAIN}" "; creating it as an orphan."

    # A missing branch serves nothing, so every rendered file compares as added.
    published_tree="$(git hash-object -t tree -w --stdin < /dev/null)"
fi

# The temporary repository's index starts empty, so adding everything stages
# exactly the source directory's files.
git --work-tree="${source_dir}" add -A

rendered_tree="$(git write-tree)"

# One "<status> <path>" line per file that differs: A added, D withdrawn, any
# other letter changed. A file that matches the branch has no line.
file_changes="$(git diff-tree -r --name-status "${published_tree}" "${rendered_tree}")"

withdrawn_files="$(awk -F '\t' '$1 == "D" { print $2 }' <<< "${file_changes}")"

if [[ -n "${withdrawn_files}" ]]; then

    exit_with_error "${branch} on ${repository} serves ${withdrawn_files//$'\n'/, }," \
        "which this run did not render. Publishing would break every badge reading them." \
        "To retire a figure, delete its file from ${branch} by hand once nothing links to it."
fi

rendered_files="$(git ls-tree -r --name-only "${rendered_tree}")"

log_rendered_file_changes "${file_changes}" "${rendered_files}"

if [[ -z "${file_changes}" ]]; then

    log_notice "${branch} on ${repository} already holds these files; nothing to publish."
    exit 0
fi

# No parent, so the new commit replaces the branch's single commit rather than
# following it.
rendered_commit="$(git \
    -c user.name="${COMMITTER_NAME}" \
    -c user.email="${COMMITTER_EMAIL}" \
    commit-tree -m "${COMMIT_MESSAGE}" "${rendered_tree}")"

retry_or_exit "push ${branch} to ${repository}" \
    push_rendered_commit "${remote_url}" "${branch_ref}" "${published_commit}" "${rendered_commit}" "${basic_credential}"

log_notice "published ${rendered_commit} to ${branch} on ${repository}."
