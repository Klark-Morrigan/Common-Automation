#!/usr/bin/env bash
# Publishes a directory of rendered badge files as the whole content of one
# branch, so shields can fetch each file from raw.githubusercontent.com.
#
# Usage: publish-badge-branch.sh <source-dir> <branch>
#
# Inputs read from the environment:
#   GITHUB_REPOSITORY  owner/name of the repository published to.
#   GH_TOKEN           token the lookup and push authenticate with. Pushing
#                      needs contents: write on GITHUB_REPOSITORY.
#   RETRY_*            optional retry tuning, read by retry.sh's
#                      retry_command. Default classifiers: network and
#                      HTTP 5xx.
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
# is left alone, and a caller with none can publish too. The token travels
# only in the URL of each call, never in a remote, so nothing written to disk
# holds it after the run.
#
# Exits non-zero, publishing nothing, when <source-dir> is missing, holds no
# file or lacks a published one, <branch> is not a valid branch name, or the
# lookup or push fails.

set -euo pipefail

readonly SCRIPT_NAME="publish-badge-branch"
readonly GITHUB_HOST="github.com"

# The identity GitHub shows for commits a workflow's own token makes.
readonly COMMITTER_NAME="github-actions[bot]"
readonly COMMITTER_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

readonly COMMIT_MESSAGE="Publish badge figures"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=../../lib/retry.sh
source "${repo_root}/.github/lib/retry.sh"

source_dir="${1:?${SCRIPT_NAME}: source directory required}"
branch="${2:?${SCRIPT_NAME}: branch required}"
repository="${GITHUB_REPOSITORY:?${SCRIPT_NAME}: GITHUB_REPOSITORY is required}"
token="${GH_TOKEN:?${SCRIPT_NAME}: GH_TOKEN is required}"

if [[ ! -d "${source_dir}" ]]; then

    echo "::error::${SCRIPT_NAME}: source directory '${source_dir}' does not exist." >&2
    exit 1
fi

# A directory holding no file would publish an empty branch, and every badge
# reading from it would break rather than keep its last good figure. Folders
# alone do not count: git stages files only.
first_source_file="$(find "${source_dir}" -type f -print -quit)"

if [[ -z "${first_source_file}" ]]; then

    echo "::error::${SCRIPT_NAME}: source directory '${source_dir}' holds no file." >&2
    exit 1
fi

if ! git check-ref-format --branch "${branch}" > /dev/null 2>&1; then

    echo "::error::${SCRIPT_NAME}: '${branch}' is not a valid branch name." >&2
    exit 1
fi

# Absolute, because git reads it as a work tree from another directory.
source_dir="$(cd "${source_dir}" && pwd)"

branch_ref="refs/heads/${branch}"
remote_url="https://x-access-token:${token}@${GITHUB_HOST}/${repository}.git"

# A rejected token fails the call rather than leaving it waiting on a password
# prompt.
export GIT_TERMINAL_PROMPT=0
export RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-classify_network:classify_http_5xx}"

work_repo="$(mktemp -d)"
trap 'rm -rf "${work_repo}"' EXIT

git init -q --bare "${work_repo}"

# Runs git against the temporary repository. Emptying credential.helper keeps
# a helper on the runner from prompting for the token-bearing URL or storing
# the token it carries.
run_git_in_work_repo() {

    git --git-dir="${work_repo}" -c credential.helper= "$@"
}

# Runs the command through retry_command and ends the script when every
# attempt fails. The command's stdout passes through, so a caller can capture
# it; a failure inside $(...) still ends the script, through set -e on the
# assignment.
#   retry_or_exit <operation> <command...>
retry_or_exit() {

    local operation="$1"
    shift

    # SC2310: set -e is off inside a function called from `if !`, which
    # retry_command needs - it inspects each failed attempt's exit itself.
    # shellcheck disable=SC2310
    if ! retry_command "${operation}" -- "$@"; then

        echo "::error::${SCRIPT_NAME}: could not ${operation}." >&2
        exit 1
    fi
}

# shellcheck disable=SC2311 # retry_or_exit exits on its own failure
published_listing="$(retry_or_exit "look up ${branch} on ${repository}" \
    run_git_in_work_repo ls-remote "${remote_url}" "${branch_ref}")"

# ls-remote matches the pattern against the tail of each ref, so only the line
# naming the branch's full ref counts. No such line means the branch does not
# exist yet.
published_commit="$(awk -v ref="${branch_ref}" '$2 == ref { print $1 }' <<< "${published_listing}")"
published_tree=""

if [[ -n "${published_commit}" ]]; then

    retry_or_exit "fetch ${branch} from ${repository}" \
        run_git_in_work_repo fetch -q --depth 1 "${remote_url}" "${published_commit}"

    published_tree="$(run_git_in_work_repo rev-parse "${published_commit}^{tree}")"
fi

# The temporary repository's index starts empty, so adding everything stages
# exactly the source directory's files.
run_git_in_work_repo --work-tree="${source_dir}" add -A

rendered_tree="$(run_git_in_work_repo write-tree)"

if [[ -n "${published_tree}" ]]; then

    withdrawn_files="$(run_git_in_work_repo diff-tree -r --name-only --diff-filter=D \
        "${published_tree}" "${rendered_tree}")"

    if [[ -n "${withdrawn_files}" ]]; then

        echo "::error::${SCRIPT_NAME}: ${branch} on ${repository} serves ${withdrawn_files//$'\n'/, }," \
            "which '${source_dir}' lacks. Publishing would break every badge reading it." \
            "To retire a figure, delete its file from ${branch} by hand once nothing links to it." >&2
        exit 1
    fi
fi

if [[ "${published_tree}" == "${rendered_tree}" ]]; then

    echo "::notice::${SCRIPT_NAME}: ${branch} on ${repository} already holds these files; nothing to publish."
    exit 0
fi

# No parent, so the new commit replaces the branch's single commit rather than
# following it.
rendered_commit="$(run_git_in_work_repo \
    -c user.name="${COMMITTER_NAME}" \
    -c user.email="${COMMITTER_EMAIL}" \
    commit-tree -m "${COMMIT_MESSAGE}" "${rendered_tree}")"

# An empty lease value means the branch must not exist yet.
retry_or_exit "push ${branch} to ${repository}" \
    run_git_in_work_repo push -q \
    --force-with-lease="${branch_ref}:${published_commit}" \
    "${remote_url}" "${rendered_commit}:${branch_ref}"

echo "::notice::${SCRIPT_NAME}: published ${branch} on ${repository}."
