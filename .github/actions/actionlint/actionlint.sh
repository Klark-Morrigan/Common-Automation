#!/usr/bin/env bash
# Runs actionlint over the caller repo's GitHub Actions surface:
# every workflow YAML under .github/workflows/. Composite actions
# under .github/actions/ are linted transitively - actionlint follows
# `uses: ./.github/actions/...` references from the workflows it
# checks. Passing composite action.yml files as positional args does
# NOT work: actionlint treats positional args as workflows and rejects
# the composite schema ("jobs section is missing", etc.). Discovery is
# therefore workflow-only here.
#
# Single source of truth for the actionlint invocation - the composite
# wrapper (action.yml) and the local pre-push runner
# (scripts/_run-lint-yaml-and-bash.sh) both exec this file so the discovery rules
# and docker arguments cannot drift between CI and local.
#
# Uses the pinned rhysd/actionlint Docker image, fetched through
# lib/ensure-docker-image.sh - the version comes from
# .github/lib/versions.env via the shared getter so a bump there
# propagates to every consumer in one commit. No native install path
# in the composite action: the image is small, pinned, and avoids a
# per-runner toolchain step.
#
# Skips silently with a `::notice::` when no workflows exist, so
# consumers can wire the workflow in before they have any workflows
# of their own.
#
# Usage: ./actionlint.sh

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

# -maxdepth 1 mirrors GitHub's own loader - only top-level *.yml under
# .github/workflows/ is a workflow. Explicit discovery (rather than
# letting actionlint auto-scan) keeps the absent-directory skip branch
# observable and makes "what we lint" auditable in one place.
files=""

if [[ -d "${workflows_dir}" ]]; then

    files="$(find "${workflows_dir}" -maxdepth 1 -type f \
        \( -name '*.yml' -o -name '*.yaml' \))"
fi

if [[ -z "${files}" ]]; then

    echo "::notice::no workflow YAML files under ${workflows_dir}, skipping"
    exit 0
fi

version="$("${repo_root}/.github/lib/get-tool-version.sh" ACTIONLINT_VERSION)"
image="rhysd/actionlint:${version}"

# actionlint ships an official image, so the fetch is a pull, not a build.
ensure_docker_image "${image}" pull "${image}"

mapfile -t workflow_files <<< "${files}"

host_dir="$(resolve_docker_host_path "${PWD}")"

echo "Linting ${#workflow_files[@]} workflow(s) in ${host_dir}."

# MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the container's
# /repo paths as Windows ones; the host side is already resolved. Linting
# neither writes nor needs the network, so a compromised image can do
# neither. -color keeps actionlint's annotations readable when the host
# terminal supports it; GitHub's log viewer renders the ANSI cleanly.
MSYS_NO_PATHCONV=1 docker run --rm \
    --network none \
    -v "${host_dir}:/repo:ro" \
    -w /repo \
    "${image}" \
    -color \
    "${workflow_files[@]}"
