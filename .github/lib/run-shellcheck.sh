#!/usr/bin/env bash
# Runs shellcheck natively when it is installed, else through its pinned
# Docker image. Sourced, not executed: defines run_shellcheck.
#
# CI runners have shellcheck; Git Bash on Windows does not, and a developer
# there may have only Docker Desktop. Choosing here, at the one call that
# lints, lets each lint helper keep its own file discovery for both cases.
# The image cannot run those helpers itself: it is Alpine with no bash.

# shellcheck source=SCRIPTDIR/resolve-docker-host-path.sh
source "${BASH_SOURCE[0]%/*}/resolve-docker-host-path.sh"

# Runs shellcheck with the given arguments and returns its status. The files
# must be named relative to the current folder, which the Docker branch mounts
# as the container's working folder.
#   run_shellcheck <shellcheck argument...>
run_shellcheck() {

    local -r shellcheck_image="koalaman/shellcheck:v0.10.0"
    local host_dir

    if command -v shellcheck > /dev/null 2>&1; then

        shellcheck "$@"
        return $?
    fi

    host_dir="$(resolve_docker_host_path "${PWD}")"

    echo "shellcheck is not on PATH; running ${shellcheck_image} over ${host_dir}." >&2

    # MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the container's
    # /work path as a Windows one; the host side is already resolved.
    MSYS_NO_PATHCONV=1 docker run --rm \
        -v "${host_dir}:/work" \
        -w /work \
        "${shellcheck_image}" \
        "$@"
}
