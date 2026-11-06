#!/usr/bin/env bash
# shellcheck disable=SC2154
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

# shellcheck source=SCRIPTDIR/_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=SCRIPTDIR/_run-recorded-check.sh
source "${script_dir}/_run-recorded-check.sh"

# shellcheck source=SCRIPTDIR/_report-check-summary.sh
source "${script_dir}/_report-check-summary.sh"

run_bats() {

    if command -v bats >/dev/null 2>&1; then
        bats --pretty --recursive "${repo_root}"
        return
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "Neither bats nor docker is available. Install one to run tests." >&2
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "Docker CLI is installed but the daemon is not running." >&2
        return 1
    fi

    # shellcheck source=SCRIPTDIR/../.github/lib/resolve-docker-host-path.sh
    source "${common_automation_root}/.github/lib/resolve-docker-host-path.sh"

    local host_repo_root
    local version

    host_repo_root="$(resolve_docker_host_path "${repo_root}")"

    # The same pin CI's bats install reads, so local and CI cannot drift.
    # `set -e` is off in here, so a missing pin returns on its own.
    version="$("${common_automation_root}/.github/lib/get-tool-version.sh" BATS_VERSION)" ||
        return

    # -e TERM=xterm: --pretty calls tput for cursor positioning; tput
    # exits non-zero without TERM, which crashes bats.
    MSYS_NO_PATHCONV=1 docker run --rm \
        -e TERM=xterm \
        -v "${host_repo_root}:/code" \
        "bats/bats:${version}" \
        --pretty --recursive /code
}

run_recorded_check "bats" run_bats
report_check_summary "bash tests"
