#!/usr/bin/env bash
# Runs yamllint over the caller repo's plain YAML surface: every
# *.yml / *.yaml file outside a curated exclude list. The excludes
# cover surfaces already linted by sibling composites
# (.github/workflows/, .github/actions/) and directories that are
# not first-party source (.git/, .venv/, collections/, node_modules/).
# Keeping the exclude list in the composite means every consumer
# inherits the same shape without re-stating it per repo.
#
# Single source of truth for the yamllint invocation - the composite
# wrapper (action.yml) and the local pre-push runner
# (scripts/_run-lint-yaml-and-bash.sh) both exec this file so discovery, excludes,
# config resolution, and docker arguments cannot drift between CI
# and local.
#
# Uses a pinned in-repo Docker image - the version comes from
# .github/lib/versions.env via the shared getter so a bump there
# propagates to every consumer in one commit. No native install path
# in the composite action: the image is small, pinned, and avoids a
# per-runner toolchain step (same rationale as actionlint).
#
# Distribution: the upstream cytopia/yamllint image only tags by
# major version, which cannot satisfy the repo's exact-version pin
# contract. To keep the same docker-only ergonomics actionlint has,
# this action ships its own Dockerfile that pip-installs the pinned
# yamllint==<version> from PyPI at build time. The image is tagged
# common-automation/yamllint:<version> and only rebuilt when the pinned
# tag changes - subsequent runs reuse the cached image (same shape
# action-validator uses for the same reason).
#
# Config resolution: a consumer-supplied .yamllint / .yamllint.yml /
# .yamllint.yaml at the repo root wins (yamllint auto-discovers it
# when run from there). Otherwise the bundled yamllint.config.yml
# next to this script applies - the strict `default` ruleset, so
# every consumer gets the same bar by default.
#
# Skips silently with a `::notice::` when no eligible YAML files
# exist, so consumers can wire the workflow in before they have any
# plain YAML of their own.
#
# Usage: ./yamllint.sh

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

# Directories the action never lints. Workflows and composite
# actions are covered by actionlint / action-validator against their
# proper schemas; the remaining entries are non-source trees that
# happen to contain YAML (virtualenvs, Ansible Galaxy collections,
# vendored node_modules) which we do not want to gate CI on.
exclude_dirs=(
    .git
    .venv
    collections
    node_modules
    .github/workflows
    .github/actions
    # Staging dir created by ci-yaml.yml's conditional sparse
    # checkout (this composite only runs in that workflow's job).
    # Holds a copy of Common-Automation's action tree and is not the
    # consumer's concern; skip.
    .common-automation
)

# Build a `find` prune expression from the exclude list so file
# discovery and the skip-when-empty branch stay in one place.
prune_expr=()
for d in "${exclude_dirs[@]}"; do

    if (( ${#prune_expr[@]} > 0 )); then
        prune_expr+=(-o)
    fi

    prune_expr+=(-path "./${d}")
done

# SC2312: `find` inside a process substitution masks its exit status.
# Tolerated here - find only fails on unreadable paths inside the repo
# checkout (which would break every other check too), and the empty-
# result branch below already covers the "nothing found" case.
# shellcheck disable=SC2312
mapfile -t files < <(
    find . \( "${prune_expr[@]}" \) -prune \
        -o -type f \( -name '*.yml' -o -name '*.yaml' \) -print
)

if (( ${#files[@]} == 0 )); then

    echo "::notice::no plain YAML files outside excluded paths, skipping"
    exit 0
fi

# Consumer-config wins so a downstream repo can tighten or relax the
# bar. yamllint resolves these names natively when -c is omitted; we
# detect explicitly here so the bundled-config branch is observable.
consumer_config=""

for candidate in .yamllint .yamllint.yml .yamllint.yaml; do

    if [[ -f "${candidate}" ]]; then

        consumer_config="${candidate}"
        break
    fi
done

version="$("${repo_root}/.github/lib/get-tool-version.sh" YAMLLINT_VERSION)"
image="common-automation/yamllint:${version}"

# stderr is left visible so a build failure (e.g. PyPI unreachable) surfaces.
ensure_docker_image "${image}" build \
    --build-arg "VERSION=${version}" \
    -t "${image}" \
    "${script_dir}"

config_args=()

if [[ -z "${consumer_config}" ]]; then
    config_args=(-c /action/yamllint.config.yml)
fi

host_dir="$(resolve_docker_host_path "${PWD}")"
host_action_dir="$(resolve_docker_host_path "${script_dir}")"

echo "Linting ${#files[@]} file(s) in ${host_dir}."

# Two mounts: the repo at /work (where yamllint sees the files and
# any consumer config) and the action dir at /action (where the
# bundled config lives). Both are read-only and the container has no
# network: linting needs neither, so a compromised image can do neither.
# MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the container's
# /work and /action paths as Windows ones; the host sides are already
# resolved.
MSYS_NO_PATHCONV=1 docker run --rm \
    --network none \
    -v "${host_dir}:/work:ro" -w /work \
    -v "${host_action_dir}:/action:ro" \
    "${image}" \
    "${config_args[@]}" \
    -- "${files[@]}"
