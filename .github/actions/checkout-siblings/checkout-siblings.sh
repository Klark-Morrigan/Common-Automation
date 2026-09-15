#!/usr/bin/env bash
# Clones a set of repositories beside the caller's checkout, so a build that
# applies shared scripts from a neighbour by relative path (e.g. Gradle's
# `apply from "${rootDir}/../Other-Repo/gradle/foo.gradle"`) finds them.
#
# Reads from the environment (set by action.yml):
#   SIBLINGS  JSON array of { repo, ref?, path }; an empty array is a no-op
#   GH_TOKEN  token the clones authenticate with
#
# Every clone is shallow: these are read for their scripts, never built from
# or pushed to, so their history is dead weight on the runner's disk.
#
# Usage: checkout-siblings.sh
#   Clones into the current directory, which is the workspace root in every
#   caller so far - the siblings have to sit next to the checkout, not
#   inside it.

set -euo pipefail

SCRIPT_NAME="checkout-siblings"

CLONE_DEPTH=1
GITHUB_HOST="github.com"

SIBLINGS="${SIBLINGS:-[]}"
GH_TOKEN="${GH_TOKEN:-}"

# An absent or empty value is the same "nothing to clone" as an empty array:
# a caller that has no neighbours states it by leaving the input alone.
if [[ -z "${SIBLINGS}" ]] || [[ "${SIBLINGS}" == "[]" ]]; then
    echo "::notice::${SCRIPT_NAME}: no sibling repos requested"
    exit 0
fi

if ! jq -e 'type == "array"' <<< "${SIBLINGS}" >/dev/null 2>&1; then
    echo "::error::${SCRIPT_NAME}: siblings must be a JSON array, got: ${SIBLINGS}" >&2
    exit 1
fi

# Read into an array first rather than piping into the loop: a piped `while`
# runs in a subshell, where an `exit 1` on a rejected entry would end only
# that subshell and let the clone loop carry on. jq's own status is checked
# here rather than inside a process substitution, where it would be lost.
if ! entriesJson=$(jq -c '.[]' <<< "${SIBLINGS}"); then
    echo "::error::${SCRIPT_NAME}: could not read the sibling entries out of: ${SIBLINGS}" >&2
    exit 1
fi

# An array holding no entries reads back as one empty line, which is not an
# entry to clone.
if [[ -z "${entriesJson}" ]]; then
    echo "::notice::${SCRIPT_NAME}: no sibling repos requested"
    exit 0
fi

mapfile -t entries <<< "${entriesJson}"

for entry in "${entries[@]}"; do
    repo=$(jq -rn --argjson e "${entry}" '$e.repo // ""')
    ref=$(jq -rn --argjson e "${entry}" '$e.ref // ""')
    path=$(jq -rn --argjson e "${entry}" '$e.path // ""')

    if [[ -z "${repo}" ]]; then
        echo "::error::${SCRIPT_NAME}: entry states no repo: ${entry}" >&2
        exit 1
    fi

    # `path` is a caller-supplied JSON value used as a clone destination, on
    # a runner whose disk outlives the job. An absolute or ../ value would
    # write outside the workspace and stay there, beyond the reach of the
    # cleanup a job runs on its own workspace, so accept only a plain
    # workspace-relative name.
    case "${path}" in
        /* | *..* | '')
            echo "::error::${SCRIPT_NAME}: refusing unsafe sibling path: '${path}'" >&2
            exit 1
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

    echo "::group::clone ${repo}${ref:+@${ref}} -> ${path}"
    git clone "${cloneArgs[@]}" \
        "https://x-access-token:${GH_TOKEN}@${GITHUB_HOST}/${repo}.git" "${path}"

    # Drop the credential the clone URL carried. git writes that URL into the
    # clone's .git/config verbatim, and on a self-hosted runner that file
    # outlives the job - so a long-lived token passed for a private neighbour
    # would sit on disk until something else happened to overwrite it. The
    # clones are read, never fetched again, so they need no working remote.
    git -C "${path}" remote set-url origin "https://${GITHUB_HOST}/${repo}.git"
    echo "::endgroup::"
done
