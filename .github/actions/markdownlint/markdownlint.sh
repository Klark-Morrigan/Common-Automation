#!/usr/bin/env bash
# Runs markdownlint-cli2 over the Markdown git tracks in the caller repo,
# against the repo's own root .markdownlint.jsonc.
#
# Single source of truth for the markdownlint invocation - the composite
# wrapper (action.yml) and the local runner both exec this file, so
# discovery, config resolution and docker arguments cannot drift between
# CI and local.
#
# Discovery is `git ls-files`, not `find` plus an exclude list. Markdown
# has generated trees (graphify-out/, .sources-cache/, build/) that are
# already untracked, so tracked files are exactly the authored surface.
#
# Config: a consumer's root file is the one-liner
#   { "extends": "../Common-Automation/.markdownlint.jsonc" }
# whose path holds only for sibling checkouts, while CI stages
# Common-Automation inside the workspace. The container recreates the
# sibling layout - the repo at /src/repo, Common-Automation at
# /src/Common-Automation - so the file the editor reads is the file CI
# reads, with no CI-only override. A missing root config fails the run:
# falling back to the family ruleset would let the editor and CI disagree.
#
# Security: both mounts are read-only, since CI never runs --fix, and the
# container has no network, since linting needs none. A compromised image
# or a malicious custom rule cannot write to the checkout or phone home.
#
# Skips silently with a `::notice::` when git tracks no Markdown, so
# consumers can wire the workflow in before they have any.
#
# Usage: ./markdownlint.sh

set -euo pipefail

readonly CONFIG_FILE=".markdownlint.jsonc"
readonly CONTAINER_COMMON_AUTOMATION_DIR="/src/Common-Automation"
readonly CONTAINER_REPO_DIR="/src/repo"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT names this repo's root when the composite
# exports it, which holds even if the action folder moves. Outside Actions
# (the local runner, an ad-hoc run) it is unset, and the path from this
# script's folder finds the same root while the layout is intact.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../lib/resolve-docker-host-path.sh
source "${repo_root}/.github/lib/resolve-docker-host-path.sh"

# shellcheck source=SCRIPTDIR/../../lib/retry.sh
source "${repo_root}/.github/lib/retry.sh"

# Checked first because the discovery below cannot tell "not a repo" from
# "no Markdown" once git's exit status is lost in the process substitution.
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "::error::${PWD} is not a git work tree; markdownlint lints the Markdown git tracks."
    exit 1
fi

# SC2312: git's exit status is masked here; the work-tree check above
# covers the only failure that matters.
# shellcheck disable=SC2312
mapfile -d '' -t tracked_files < <(git ls-files -z -- '*.md')

# A tracked file deleted from the work tree is still in the index. Locally
# that is a removal not yet staged; linting it would fail on a missing file.
files=()

for file in "${tracked_files[@]}"; do

    if [[ -f "${file}" ]]; then
        files+=("${file}")
    fi
done

if (( ${#files[@]} == 0 )); then
    echo "::notice::git tracks no Markdown files, skipping"
    exit 0
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then

    echo "::error::no ${CONFIG_FILE} at the root of ${PWD}. Add the one-line file:" \
        "{ \"extends\": \"../Common-Automation/.markdownlint.jsonc\" }"

    exit 1
fi

version="$("${repo_root}/.github/lib/get-tool-version.sh" MARKDOWNLINT_CLI2_VERSION)"
image="davidanson/markdownlint-cli2:v${version}"

# Pull explicitly on first use rather than letting `docker run` pull, so a
# retry covers the registry and can never rerun a lint that failed for real.
if ! docker image inspect "${image}" > /dev/null 2>&1; then

    echo "::notice::pulling ${image} (first run for this version)"

    RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_REGISTRY}}" \
        retry_or_exit "pull ${image}" docker pull "${image}"
fi

common_automation_dir="$(cd "${repo_root}" && pwd -P)"
physical_dir="$(pwd -P)"
host_dir="$(resolve_docker_host_path "${PWD}")"

# Common-Automation linting itself is its own sibling: one mount, at the
# path its own config already sits on.
if [[ "${physical_dir}" == "${common_automation_dir}" ]]; then
    container_dir="${CONTAINER_COMMON_AUTOMATION_DIR}"
    mounts=(-v "${host_dir}:${container_dir}:ro")
else
    container_dir="${CONTAINER_REPO_DIR}"
    mounts=(
        -v "${host_dir}:${container_dir}:ro"
        -v "$(resolve_docker_host_path "${common_automation_dir}"):${CONTAINER_COMMON_AUTOMATION_DIR}:ro"
    )
fi

echo "Linting ${#files[@]} file(s) in ${host_dir}."

# MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the container's
# /src paths as Windows ones; the host sides are already resolved. The `--`
# makes markdownlint-cli2 read every file after it as a literal path, so a
# name holding [, * or ! is linted rather than expanded as a glob.
MSYS_NO_PATHCONV=1 docker run --rm \
    --network none \
    "${mounts[@]}" \
    -w "${container_dir}" \
    "${image}" \
    -- "${files[@]}"
