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
# only in the URL of each call, never in a remote or a credential helper, so
# nothing written to disk holds it after the run.
#
# Exits non-zero, publishing nothing, when <source-dir> is missing or empty,
# <branch> is not a valid branch name, or the lookup or push fails.

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

# An empty directory would publish an empty branch, and every badge reading
# from it would break rather than keep its last good figure.
first_source_entry="$(find "${source_dir}" -mindepth 1 -print -quit)"

if [[ -z "${first_source_entry}" ]]; then

    echo "::error::${SCRIPT_NAME}: source directory '${source_dir}' is empty." >&2
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

work_repo="$(mktemp -d)"
trap 'rm -rf "${work_repo}"' EXIT

git init -q --bare "${work_repo}"

# Runs git against the temporary repository. Emptying credential.helper keeps
# a helper on the runner from prompting for the token-bearing URL or storing
# the token it carries.
run_git_in_work_repo() {

    git --git-dir="${work_repo}" -c credential.helper= "$@"
}

list_published_branch() {

    run_git_in_work_repo ls-remote "${remote_url}" "${branch_ref}"
}

fetch_published_commit() {

    run_git_in_work_repo fetch -q --depth 1 "${remote_url}" "$1"
}

push_rendered_commit() {

    # An empty lease value means the branch must not exist yet.
    run_git_in_work_repo push -q \
        --force-with-lease="${branch_ref}:${published_commit}" \
        "${remote_url}" "${rendered_commit}:${branch_ref}"
}

retry_classifiers="${RETRY_CLASSIFIERS:-classify_network:classify_http_5xx}"

# SC2310: set -e is off inside a function called from `if !`, which
# retry_command needs - it inspects each failed attempt's exit itself.
# shellcheck disable=SC2310
if ! published_listing=$(RETRY_CLASSIFIERS="${retry_classifiers}" \
    retry_command "look up ${branch} on ${repository}" -- list_published_branch); then

    echo "::error::${SCRIPT_NAME}: could not look up ${branch} on ${repository}." >&2
    exit 1
fi

# ls-remote matches the pattern against the tail of each ref, so only the line
# naming the branch's full ref counts. No such line means the branch does not
# exist yet.
published_commit="$(awk -v ref="${branch_ref}" '$2 == ref { print $1 }' <<< "${published_listing}")"

if [[ -n "${published_commit}" ]]; then

    # shellcheck disable=SC2310
    if ! RETRY_CLASSIFIERS="${retry_classifiers}" \
        retry_command "fetch ${branch} from ${repository}" -- fetch_published_commit "${published_commit}"; then

        echo "::error::${SCRIPT_NAME}: could not fetch ${branch} from ${repository}." >&2
        exit 1
    fi
fi

# The temporary repository's index starts empty, so adding everything stages
# exactly the source directory's files: one deleted since the last run drops
# off the branch.
run_git_in_work_repo --work-tree="${source_dir}" add -A

rendered_tree="$(run_git_in_work_repo write-tree)"
published_tree=""

if [[ -n "${published_commit}" ]]; then

    published_tree="$(run_git_in_work_repo rev-parse "${published_commit}^{tree}")"
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

# shellcheck disable=SC2310
if ! RETRY_CLASSIFIERS="${retry_classifiers}" \
    retry_command "push ${branch} to ${repository}" -- push_rendered_commit; then

    echo "::error::${SCRIPT_NAME}: could not push ${branch} to ${repository}." >&2
    exit 1
fi

echo "::notice::${SCRIPT_NAME}: published ${branch} on ${repository}."
