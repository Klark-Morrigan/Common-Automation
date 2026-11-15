#!/usr/bin/env bats
# Unit tests for ensure-docker-image.sh.
# Run with: bats .github/lib/ensure-docker-image.bats
#
# docker is stubbed, so each case runs the same whether or not the host has
# it, and fetches nothing.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/ensure-docker-image.sh
source "${BATS_TEST_DIRNAME}/ensure-docker-image.sh"

# shellcheck source=SCRIPTDIR/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/test-helpers/docker-stub.bash"

readonly IMAGE="example/tool:v1.2.3"

setup() {

    # No backoff, so the retried cases take no time.
    export RETRY_BACKOFF_INITIAL_SECONDS=0
    export RETRY_BACKOFF_JITTER_RATIO=0

    fetch_arguments_file="${BATS_TEST_TMPDIR}/fetch-arguments"
}

@test "skips the fetch when the image is cached" {

    install_docker_stub pull 'exit 0'

    DOCKER_STUB_IMAGE_EXIT=0 run --separate-stderr ensure_docker_image "${IMAGE}" pull "${IMAGE}"

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 0 ]
    [ -z "${stderr}" ]
}

@test "runs the docker verb with its arguments when the image is not cached" {

    install_docker_stub build "printf '%s\n' \"\$@\" > '${fetch_arguments_file}'"

    run --separate-stderr ensure_docker_image "${IMAGE}" build --build-arg VERSION=1.2.3 -t "${IMAGE}" ./context

    [ "${status}" -eq 0 ]
    [ "$(cat "${fetch_arguments_file}")" = "build
--build-arg
VERSION=1.2.3
-t
${IMAGE}
./context" ]
}

@test "says on stderr which image it fetches and how" {

    install_docker_stub pull 'exit 0'

    run --separate-stderr ensure_docker_image "${IMAGE}" pull "${IMAGE}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "Fetching ${IMAGE} with docker pull, the first run of this version here." ]
}

@test "recovers from a transient registry failure on the next attempt" {

    install_docker_stub pull 'if (( DOCKER_ATTEMPT < 2 )); then echo "dial tcp 1.2.3.4:443: i/o timeout" >&2; exit 1; fi; exit 0'

    RETRY_MAX_ATTEMPTS=3 run --separate-stderr ensure_docker_image "${IMAGE}" pull "${IMAGE}"

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 2 ]
    [[ "${stderr}" == *"retriable via classify_docker_registry"* ]]
}

# 'Permission denied' matches no registry classifier, so it is not retried.
@test "ends with the fetch's status and an error naming the operation when it fails for good" {

    install_docker_stub pull 'echo "Permission denied" >&2; exit 13'

    RETRY_MAX_ATTEMPTS=5 run --separate-stderr ensure_docker_image "${IMAGE}" pull "${IMAGE}"

    [ "${status}" -eq 13 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [[ "${stderr}" == *"permanent (exit 13)"* ]]
    [[ "${stderr}" == *"could not pull ${IMAGE}."* ]]
}

@test "a caller's own RETRY_CLASSIFIERS replaces the registry set" {

    # The transient registry signature fails for good once the caller names a
    # classifier that rejects it.
    install_docker_stub pull 'echo "dial tcp 1.2.3.4:443: i/o timeout" >&2; exit 1'
    classify_nothing_as_transient() { return 1; }

    RETRY_MAX_ATTEMPTS=3 RETRY_CLASSIFIERS=classify_nothing_as_transient \
        run --separate-stderr ensure_docker_image "${IMAGE}" pull "${IMAGE}"

    [ "${status}" -eq 1 ]
    [ "$(count_docker_attempts)" -eq 1 ]
}
