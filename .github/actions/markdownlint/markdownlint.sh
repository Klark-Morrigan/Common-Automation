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
# Config: a consumer's root file is the CONSUMER_CONFIG_LINE one-liner,
# whose `extends` path holds only for sibling checkouts, while CI stages
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
readonly CONSUMER_CONFIG_LINE='{ "extends": "../Common-Automation/.markdownlint.jsonc" }'
readonly CONTAINER_COMMON_AUTOMATION_DIR="/src/Common-Automation"
readonly CONTAINER_REPO_DIR="/src/repo"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT names this repo's root when the composite
# exports it, which holds even if the action folder moves. Outside Actions
# (the local runner, an ad-hoc run) it is unset, and the path from this
# script's folder finds the same root while the layout is intact.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../lib/ensure-docker-image.sh
source "${repo_root}/.github/lib/ensure-docker-image.sh"

# shellcheck source=SCRIPTDIR/../../lib/resolve-docker-host-path.sh
source "${repo_root}/.github/lib/resolve-docker-host-path.sh"

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

    echo "::error::no ${CONFIG_FILE} at the root of ${PWD}. Add the one-line file: ${CONSUMER_CONFIG_LINE}"

    exit 1
fi

version="$("${repo_root}/.github/lib/get-tool-version.sh" MARKDOWNLINT_CLI2_VERSION)"
image="davidanson/markdownlint-cli2:v${version}"

ensure_docker_image "${image}" pull "${image}"

common_automation_dir="$(cd "${repo_root}" && pwd -P)"
physical_dir="$(pwd -P)"
host_dir="$(resolve_docker_host_path "${PWD}")"
host_common_automation_dir="$(resolve_docker_host_path "${common_automation_dir}")"

# Common-Automation linting itself is its own sibling: one mount, at the
# path its own config already sits on.
if [[ "${physical_dir}" == "${common_automation_dir}" ]]; then
    layout="self"
    container_dir="${CONTAINER_COMMON_AUTOMATION_DIR}"
    mounts=(-v "${host_dir}:${container_dir}:ro")
else
    layout="consumer"
    container_dir="${CONTAINER_REPO_DIR}"
    mounts=(
        -v "${host_dir}:${container_dir}:ro"
        -v "${host_common_automation_dir}:${CONTAINER_COMMON_AUTOMATION_DIR}:ro"
    )
fi

echo "Linting ${#files[@]} file(s) in ${host_dir}."

# CI reads the ruleset from Common-Automation's master, a workstation from
# whatever the sibling checkout holds. Naming the copy is the first clue
# when the two disagree.
echo "Ruleset from ${host_common_automation_dir} (${layout} layout)."

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
