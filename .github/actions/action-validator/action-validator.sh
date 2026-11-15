#!/usr/bin/env bash
# Runs action-validator over the caller repo's GitHub Actions surface:
# every workflow YAML under .github/workflows/ AND every composite
# action.yml under .github/actions/*/ (mindepth 2 - a stray
# .github/actions/action.yml is ignored, matching the discovery rule
# the actionlint helper uses for workflows). action-validator validates
# both file kinds against their respective official schemas, so we feed
# it both in one invocation.
#
# Single source of truth for the action-validator invocation - the
# composite wrapper (action.yml) and the local pre-push runner
# (scripts/_run-lint-yaml-and-bash.sh) both exec this file so the discovery rules
# and docker arguments cannot drift between CI and local.
#
# Distribution: mpalmer/action-validator has no official Docker image
# and its npm channel lags the GitHub releases. To keep the same docker-only ergonomics actionlint has, this
# action ships its own Dockerfile that pulls the pinned linux binary
# from GitHub releases at build time. The image is tagged
# common-automation/action-validator:<version> and only rebuilt when the
# pinned tag changes - subsequent runs reuse the cached image.
#
# Skips silently with a `::notice::` when neither workflows nor
# composite actions exist, so consumer repos with only one of those
# surfaces still work without configuration.
#
# Usage: ./action-validator.sh

set -euo pipefail

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

workflows_dir=".github/workflows"
actions_dir=".github/actions"

# Explicit discovery (rather than glob expansion in the docker
# command) keeps the absent-directory skip branch observable and makes
# "what we validate" auditable in one place. Workflows: top-level only
# (-maxdepth 1) mirrors GitHub's loader. Composite actions: -mindepth 2
# so .github/actions/<name>/action.yml is picked up but a stray
# .github/actions/action.yml is not.
files=()
# SC2312: collect each find's output into a variable first so its exit
# status is observable to set -e, then feed the variable into the loop.
# Reading directly from a process substitution would mask a find failure.
if [[ -d "${workflows_dir}" ]]; then

    workflow_hits="$(find "${workflows_dir}" -maxdepth 1 -type f \
        \( -name '*.yml' -o -name '*.yaml' \))"

    while IFS= read -r f; do
        [[ -n "${f}" ]] && files+=("${f}")
    done <<< "${workflow_hits}"
fi

if [[ -d "${actions_dir}" ]]; then

    action_hits="$(find "${actions_dir}" -mindepth 2 -type f \
        \( -name 'action.yml' -o -name 'action.yaml' \))"

    while IFS= read -r f; do
        [[ -n "${f}" ]] && files+=("${f}")
    done <<< "${action_hits}"
fi

if (( ${#files[@]} == 0 )); then

    echo "::notice::no workflow or composite action YAML found, skipping"
    exit 0
fi

version="$("${repo_root}/.github/lib/get-tool-version.sh" ACTION_VALIDATOR_VERSION)"
image="common-automation/action-validator:${version}"

# stderr is left visible so a build failure (e.g. network error fetching
# the release binary) surfaces.
ensure_docker_image "${image}" build \
    --build-arg "VERSION=${version}" \
    -t "${image}" \
    "${script_dir}"

host_dir="$(resolve_docker_host_path "${PWD}")"

echo "Validating ${#files[@]} file(s) in ${host_dir}."

# MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the container's
# /repo paths as Windows ones; the host side is already resolved.
# Validating neither writes nor needs the network, so a compromised image
# can do neither. The discovered file list is passed as positional args -
# action-validator picks the schema (workflow vs composite) per file.
MSYS_NO_PATHCONV=1 docker run --rm \
    --network none \
    -v "${host_dir}:/repo:ro" \
    -w /repo \
    "${image}" \
    "${files[@]}"
