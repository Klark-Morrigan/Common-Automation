#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154 (referenced but not assigned): script_dir,
# common_automation_root and repo_root are set by the sourced
# _run-common.sh, which shellcheck cannot follow through the
# command-substitution source path.

# Test half of the local CI suite: runs the *.bats suites git tracks in the
# target repo, in the pinned bats image. A bats on the host's PATH is never
# used: its version can differ from CI's pin, and on Git Bash it runs the
# suites one at a time. It finds them through the same list_bats_suites the
# bats job of ci-bash.yml runs, so an untracked suite fails neither run.
# The lint half lives in
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

# shellcheck source=SCRIPTDIR/../.github/lib/list-bats-suites.sh
source "${common_automation_root}/.github/lib/list-bats-suites.sh"

run_bats() {

    local suites=()
    local container_suites=()
    local suite

    cd "${repo_root}" || return

    # Checked first because the discovery below cannot tell "not a repo" from
    # "no suites" once git's exit status is lost in the process substitution.
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "${repo_root} is not a git work tree; the bats run covers the suites git tracks." >&2
        return 1
    fi

    # SC2312: git's exit status is masked here; the work-tree check above
    # covers the only failure that matters.
    # shellcheck disable=SC2312
    mapfile -t suites < <(list_bats_suites .)

    # bats handed no files fails rather than passing.
    if (( ${#suites[@]} == 0 )); then
        echo "git tracks no bats suites, skipping."
        return 0
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker is not available. Install it to run the bats suites in the pinned image." >&2
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "Docker CLI is installed but the daemon is not running." >&2
        return 1
    fi

    # shellcheck source=SCRIPTDIR/../.github/lib/resolve-docker-host-path.sh
    source "${common_automation_root}/.github/lib/resolve-docker-host-path.sh"

    # shellcheck source=SCRIPTDIR/../.github/lib/ensure-docker-image.sh
    source "${common_automation_root}/.github/lib/ensure-docker-image.sh"

    local image_dir="${script_dir}/bats-image"
    local host_repo_root
    local version
    local dockerfile_checksum
    local image
    local job_count

    host_repo_root="$(resolve_docker_host_path "${repo_root}")"

    # The same pin CI's bats install reads, so local and CI cannot drift.
    # `set -e` is off in here, so a missing pin returns on its own.
    version="$("${common_automation_root}/.github/lib/get-tool-version.sh" BATS_VERSION)" ||
        return

    # The tag carries the Dockerfile's checksum beside the pin, so an edit to
    # the image misses the cache as a version bump does.
    dockerfile_checksum="$(cksum < "${image_dir}/Dockerfile")" || return
    image="common-automation/bats:${version}-${dockerfile_checksum%% *}"

    ensure_docker_image "${image}" build \
        --build-arg "VERSION=${version}" \
        -t "${image}" \
        "${image_dir}"

    # One job per host core. Each suite file runs whole in one job, since a
    # suite's cases may share its setup_file fixtures.
    job_count="$(nproc 2> /dev/null || echo 1)"

    for suite in "${suites[@]}"; do
        container_suites+=("/code/${suite}")
    done

    # The checkout is mounted read-only and the container has no network:
    # a suite writes only to its own temp folder and fetches nothing.
    # -e TERM=xterm: --pretty calls tput for cursor positioning; tput
    # exits non-zero without TERM, which crashes bats.
    MSYS_NO_PATHCONV=1 docker run --rm \
        --network none \
        -e TERM=xterm \
        -v "${host_repo_root}:/code:ro" \
        "${image}" \
        --pretty --jobs "${job_count}" --no-parallelize-within-files "${container_suites[@]}"
}

run_recorded_check "bats" run_bats
report_check_summary "bash tests"
