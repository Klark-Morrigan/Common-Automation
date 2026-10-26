#!/usr/bin/env bash
# Runs shellcheck through its pinned Docker image, in CI and locally alike.
# Sourced, not executed: defines run_shellcheck.
#
# The version comes from versions.env, never from the machine. The install on
# a runner changes when GitHub moves the runner image, which turns unchanged
# code red, and a local install drifts on its own schedule. Bumping the pin is
# the one way a new version arrives, so its new findings land in that change.
# The image cannot run the lint helpers themselves: it is Alpine with no bash.

# shellcheck source=SCRIPTDIR/resolve-docker-host-path.sh
source "${BASH_SOURCE[0]%/*}/resolve-docker-host-path.sh"

# shellcheck source=SCRIPTDIR/retry.sh
source "${BASH_SOURCE[0]%/*}/retry.sh"

# Runs shellcheck with the given arguments and returns its status. The files
# must be named relative to the current folder, which is mounted as the
# container's working folder.
#   run_shellcheck <shellcheck argument...>
run_shellcheck() {

    local version image host_dir

    version="$("${BASH_SOURCE[0]%/*}/get-shellcheck-version.sh")"
    image="koalaman/shellcheck:v${version}"

    # Pulled on its own rather than by docker run, so a retry can never rerun
    # a lint that failed for real.
    if ! docker image inspect "${image}" > /dev/null 2>&1; then

        echo "Pulling ${image}, the first run of this version here." >&2

        RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_REGISTRY}}" \
            retry_or_exit "pull ${image}" docker pull "${image}"
    fi

    host_dir="$(resolve_docker_host_path "${PWD}")"

    echo "Running ${image} over ${host_dir}." >&2

    # MSYS_NO_PATHCONV stops Git Bash on Windows rewriting the container's
    # /work path as a Windows one; the host side is already resolved.
    MSYS_NO_PATHCONV=1 docker run --rm \
        -v "${host_dir}:/work" \
        -w /work \
        "${image}" \
        "$@"
}
