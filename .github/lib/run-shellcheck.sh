#!/usr/bin/env bash
# Runs shellcheck through its pinned Docker image, in CI and locally alike.
# Sourced, not executed: defines run_shellcheck.
#
# The version comes from versions.env, never from the machine. The install on
# a runner changes when GitHub moves the runner image, which turns unchanged
# code red, and a local install drifts on its own schedule. Bumping the pin is
# the one way a new version arrives, so its new findings land in that change.
# The image cannot run the lint helpers themselves: it is Alpine with no bash.

# shellcheck source=SCRIPTDIR/ensure-docker-image.sh
source "${BASH_SOURCE[0]%/*}/ensure-docker-image.sh"

# shellcheck source=SCRIPTDIR/resolve-docker-host-path.sh
source "${BASH_SOURCE[0]%/*}/resolve-docker-host-path.sh"

# Runs shellcheck with the given arguments and returns its status. The files
# must be named relative to the current folder, which is mounted as the
# container's working folder.
#   run_shellcheck <shellcheck argument...>
run_shellcheck() {

    local version image host_dir

    version="$("${BASH_SOURCE[0]%/*}/get-tool-version.sh" SHELLCHECK_VERSION)"
    image="koalaman/shellcheck:v${version}"

    ensure_docker_image "${image}" pull "${image}"

    host_dir="$(resolve_docker_host_path "${PWD}")"

    echo "Running ${image} over ${host_dir}." >&2

    # MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the container's
    # /work path as a Windows one; the host side is already resolved. Linting
    # neither writes nor needs the network, so a compromised image can do
    # neither.
    MSYS_NO_PATHCONV=1 docker run --rm \
        --network none \
        -v "${host_dir}:/work:ro" \
        -w /work \
        "${image}" \
        "$@"
}
