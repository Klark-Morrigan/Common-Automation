#!/usr/bin/env bash
# Fetches a pinned Docker image once, through the retry primitive. Sourced,
# not executed: defines ensure_docker_image.
#
# Every lint helper runs a pinned image, pulled from a registry or built from
# an in-repo Dockerfile. The fetch happens on its own rather than inside
# docker run, so a retry covers the registry and can never rerun a lint that
# failed for real. The image's tag carries its version, so a bump misses the
# cache and fetches the new one; an unchanged pin costs one image inspect.

# shellcheck source=SCRIPTDIR/retry.sh
source "${BASH_SOURCE[0]%/*}/retry.sh"

# Runs `docker <verb> <argument...>` unless <image> is already cached. When
# every attempt fails it ends the calling script, the error annotation naming
# that script and "<verb> <image>".
#   ensure_docker_image <image> <docker verb> <verb argument...>
# For example:
#   ensure_docker_image "${image}" pull "${image}"
#   ensure_docker_image "${image}" build --build-arg "VERSION=${version}" -t "${image}" "${script_dir}"
ensure_docker_image() {

    local image="$1"
    local verb="$2"

    shift 2

    if docker image inspect "${image}" > /dev/null 2>&1; then
        return 0
    fi

    echo "Fetching ${image} with docker ${verb}, the first run of this version here." >&2

    RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_REGISTRY}}" \
        retry_or_exit "${verb} ${image}" docker "${verb}" "$@"
}
