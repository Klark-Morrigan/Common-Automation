#!/usr/bin/env bash
# Clones a set of repositories beside the caller's checkout, so a build that
# applies shared scripts from a neighbour by relative path (e.g. Gradle's
# `apply from "${rootDir}/../Other-Repo/gradle/foo.gradle"`) finds them.
#
# Reads from the environment (set by action.yml):
#   SIBLINGS  JSON array of { repo, ref?, path }; an empty array is a no-op
#   GH_TOKEN  token the clones authenticate with. Cleared once read, so no
#             process the script starts inherits it.
#
# Every clone is shallow: these are read for their scripts, never built from
# or pushed to, so their history is dead weight on the runner's disk.
#
# The token reaches each clone as an HTTP header, as run-git-with-token.sh
# says, never in the clone URL. A URL would put it on git's command line, where
# every user on the runner can read it, and in the clone's .git/config, which
# on a self-hosted runner outlives the job.
#
# Usage: checkout-siblings.sh
#   Clones into the current directory, which is the workspace root in every
#   caller so far - the siblings have to sit next to the checkout, not
#   inside it.

set -euo pipefail

CLONE_DEPTH=1
GITHUB_HOST="github.com"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../lib/create-masked-basic-credential.sh
source "${repo_root}/.github/lib/create-masked-basic-credential.sh"

# shellcheck source=SCRIPTDIR/../../lib/run-git-with-token.sh
source "${repo_root}/.github/lib/run-git-with-token.sh"

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

SIBLINGS="${SIBLINGS:-[]}"
token="${GH_TOKEN:-}"

# Read once, then cleared, so jq and the other processes this script starts do
# not inherit it.
unset GH_TOKEN

# An absent or empty value is the same "nothing to clone" as an empty array:
# a caller that has no neighbours states it by leaving the input alone.
if [[ -z "${SIBLINGS}" ]] || [[ "${SIBLINGS}" == "[]" ]]; then

    log_notice "no sibling repos requested"
    exit 0
fi

if ! jq -e 'type == "array"' <<< "${SIBLINGS}" >/dev/null 2>&1; then

    exit_with_error "siblings must be a JSON array, got: ${SIBLINGS}"
fi

# Read into an array first rather than piping into the loop: a piped `while`
# runs in a subshell, where an `exit 1` on a rejected entry would end only
# that subshell and let the clone loop carry on. jq's own status is checked
# here rather than inside a process substitution, where it would be lost.
if ! entriesJson=$(jq -c '.[]' <<< "${SIBLINGS}"); then

    exit_with_error "could not read the sibling entries out of: ${SIBLINGS}"
fi

# An array holding no entries reads back as one empty line, which is not an
# entry to clone.
if [[ -z "${entriesJson}" ]]; then

    log_notice "no sibling repos requested"
    exit 0
fi

mapfile -t entries <<< "${entriesJson}"

create_masked_basic_credential "${token}"

for entry in "${entries[@]}"; do

    repo=$(jq -rn --argjson e "${entry}" '$e.repo // ""')
    ref=$(jq -rn --argjson e "${entry}" '$e.ref // ""')
    path=$(jq -rn --argjson e "${entry}" '$e.path // ""')

    if [[ -z "${repo}" ]]; then

        exit_with_error "entry states no repo: ${entry}"
    fi

    # `path` is a caller-supplied JSON value used as a clone destination, on
    # a runner whose disk outlives the job. An absolute or ../ value would
    # write outside the workspace and stay there, beyond the reach of the
    # cleanup a job runs on its own workspace, so accept only a plain
    # workspace-relative name.
    case "${path}" in
        /* | *..* | '')
            exit_with_error "refusing unsafe sibling path: '${path}'"
            ;;
        *)
            # A plain workspace-relative name, which is the only shape that
            # gets past the rejections above.
            ;;
    esac

    # Built as an array so the optional --branch pair is either two
    # arguments or none, with no unquoted expansion deciding which.
    cloneArgs=(--depth "${CLONE_DEPTH}")

    if [[ -n "${ref}" ]]; then
        cloneArgs+=(--branch "${ref}")
    fi

    remoteUrl="https://${GITHUB_HOST}/${repo}.git"

    echo "::group::clone ${repo}${ref:+@${ref}} -> ${path}"
    run_git_with_token "${remoteUrl}" "${basic_credential}" clone "${cloneArgs[@]}" "${remoteUrl}" "${path}"
    echo "::endgroup::"
done
