#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154 (referenced but not assigned): script_dir,
# common_automation_root and repo_root are set by the sourced
# _run-common.sh, which shellcheck cannot follow through the
# command-substitution source path.

# Test half of the local CI suite: runs test-bats.sh, the helper of CI's bats
# job, against the target repo, inside a pinned image with the tools CI's
# runner has. A bats on the host's PATH is never used: its version can differ
# from CI's pin, and under Git Bash it runs the suites one at a time.
#
# The lint half lives in _run-lint-yaml-and-bash.sh; run-ci-yaml-and-bash.sh
# runs both. Underscore-prefixed because it is a building block invoked by
# that orchestrator and by the per-repo run-tests-bash.sh shims, not a
# standalone entry name.

set -euo pipefail

# shellcheck source=SCRIPTDIR/_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=SCRIPTDIR/_run-recorded-check.sh
source "${script_dir}/_run-recorded-check.sh"

# shellcheck source=SCRIPTDIR/_report-check-summary.sh
source "${script_dir}/_report-check-summary.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/ensure-docker-image.sh
source "${common_automation_root}/.github/lib/ensure-docker-image.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/resolve-docker-host-path.sh
source "${common_automation_root}/.github/lib/resolve-docker-host-path.sh"

readonly BATS_IMAGE_REPOSITORY="common-automation/bats"

# Where the container sees the target repo and Common-Automation's .github.
readonly CONTAINER_REPO_DIR="/code"
readonly CONTAINER_GITHUB_DIR="/common-automation/.github"

# Holds test-bats.sh and the Dockerfile of the image it runs in here.
test_bats_dir="${common_automation_root}/.github/actions/test-bats"

# Fails, saying why, unless docker is installed and its daemon answers.
#   require_docker_daemon
require_docker_daemon() {

    if ! command -v docker > /dev/null 2>&1; then
        echo "Docker is not available. Install it to run the bats suites in the pinned image." >&2
        return 1
    fi

    if ! docker info > /dev/null 2>&1; then
        echo "Docker CLI is installed but the daemon is not running." >&2
        return 1
    fi
}

# Removes every other tag of the bats image, so an edit or a pin bump does not
# leave the old image behind. A tag still in use stays, docker saying why.
#   remove_stale_bats_images <current image>
remove_stale_bats_images() {

    local current_image="$1"
    local image

    # SC2312: a failed listing removes nothing, which is the safe outcome.
    # shellcheck disable=SC2312
    while IFS= read -r image; do

        if [[ "${image}" != "${current_image}" ]]; then

            echo "Removing the stale ${image}." >&2
            docker image rm "${image}" > /dev/null
        fi
    done < <(docker image ls "${BATS_IMAGE_REPOSITORY}" --filter dangling=false --format '{{.Repository}}:{{.Tag}}')
}

# Builds the bats image unless it is cached, removes its stale tags, and prints
# its name. The tag carries the Dockerfile's checksum beside the pin, so an edit
# to the image misses the cache as a version bump does.
#   ensure_bats_image
# shellcheck disable=SC2310 # set -e is off under run_recorded_check; || return is the failure check
ensure_bats_image() {

    local version
    local dockerfile_checksum
    local image

    # The same pin CI's bats install reads, so local and CI cannot drift.
    version="$("${common_automation_root}/.github/lib/get-tool-version.sh" BATS_VERSION)" || return
    dockerfile_checksum="$(cksum < "${test_bats_dir}/Dockerfile")" || return
    image="${BATS_IMAGE_REPOSITORY}:${version}-${dockerfile_checksum%% *}"

    # The build's output goes to stderr, since stdout carries the name.
    ensure_docker_image "${image}" build \
        --build-arg "VERSION=${version}" \
        -t "${image}" \
        "${test_bats_dir}" >&2 || return

    remove_stale_bats_images "${image}"

    echo "${image}"
}

# Runs test-bats.sh over the target repo in <image>. It spreads the suites over
# the cores itself, as in CI; inside the container nproc counts the Docker VM's
# cores, which a .wslconfig can set below the host's.
#   run_suites_in_image <image>
# shellcheck disable=SC2310 # set -e is off under run_recorded_check; || return is the failure check
run_suites_in_image() {

    local image="$1"
    local host_repo_dir
    local host_github_dir

    host_repo_dir="$(resolve_docker_host_path "${repo_root}")" || return
    host_github_dir="$(resolve_docker_host_path "${common_automation_root}/.github")" || return

    echo "Running the suites of ${repo_root}, mounted at ${CONTAINER_REPO_DIR}, in ${image}."

    # Both mounts are read-only and the container has no network: a suite
    # writes only to its own temp folder and fetches nothing.
    # -e TERM=xterm: --pretty calls tput for cursor positioning; tput
    # exits non-zero without TERM, which crashes bats.
    MSYS_NO_PATHCONV=1 docker run --rm \
        --network none \
        -e TERM=xterm \
        -v "${host_repo_dir}:${CONTAINER_REPO_DIR}:ro" \
        -v "${host_github_dir}:${CONTAINER_GITHUB_DIR}:ro" \
        -w "${CONTAINER_REPO_DIR}" \
        "${image}" \
        bash "${CONTAINER_GITHUB_DIR}/actions/test-bats/test-bats.sh" . --pretty
}

# shellcheck disable=SC2310 # set -e is off under run_recorded_check; || return is the failure check
run_bats() {

    local image

    require_docker_daemon || return

    # Captured, so the exit ensure_docker_image makes when every attempt fails
    # ends only this subshell: the check fails, and the run still reaches its
    # summary.
    image="$(ensure_bats_image)" || return

    run_suites_in_image "${image}"
}

run_recorded_check "bats" run_bats
report_check_summary "bash tests" "${failed_checks[@]}"
