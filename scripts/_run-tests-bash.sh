#!/usr/bin/env bash
# shellcheck disable=SC2310,SC2154
# SC2310 (set -e disabled inside a function called from `if !`) is
# intentional: run_bats runs from `if ! run_bats; then` so a test
# failure is reported cleanly rather than aborting mid-trap.
# SC2154 (referenced but not assigned): script_dir,
# common_automation_root and repo_root are set by the sourced
# _run-common.sh, which shellcheck cannot follow through the
# command-substitution source path.

# Test half of the local CI suite: runs every *.bats suite in the target
# repo - native bats if on PATH, else the pinned docker image. Mirrors
# the bats job of ci-bash.yml. The lint half lives in
# _run-lint-yaml-and-bash.sh; run-ci-yaml-and-bash.sh runs both.
# Underscore-prefixed because it is a building block invoked by that
# orchestrator and by the per-repo run-tests-bash.sh shims, not a
# standalone entry name.

set -euo pipefail

# shellcheck source=./_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# Resolve the canonical bats version through the same accessor the
# composite action uses, so local and CI cannot drift. The getter reads
# .github/lib/versions.env - the single source of truth.
BATS_IMAGE="bats/bats:$("${common_automation_root}/.github/lib/get-bats-version.sh")"

run_bats() {
    echo "=== bats ==="
    if command -v bats >/dev/null 2>&1; then
        bats --pretty --recursive "${repo_root}"
        return $?
    fi
    if ! command -v docker >/dev/null 2>&1; then
        echo "Neither bats nor docker is available. Install one to run tests." >&2
        return 1
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "Docker CLI is installed but the daemon is not running." >&2
        return 1
    fi
    # -e TERM=xterm: --pretty calls tput for cursor positioning; tput
    # exits non-zero without TERM, which crashes bats.
    MSYS_NO_PATHCONV=1 docker run --rm \
        -e TERM=xterm \
        -v "${repo_root}:/code" \
        "${BATS_IMAGE}" \
        --pretty --recursive /code
}

if ! run_bats; then
    echo
    echo "FAILED (bats): bats" >&2
    exit 1
fi
echo
echo "Bash tests passed."
