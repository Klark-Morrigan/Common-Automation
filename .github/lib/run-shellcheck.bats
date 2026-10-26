#!/usr/bin/env bats
# Unit tests for run-shellcheck.sh.
# Run with: bats .github/lib/run-shellcheck.bats
#
# docker and cygpath are stubbed, so each case runs the same whether or not
# the host has them, and lints nothing.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/run-shellcheck.sh
source "${BATS_TEST_DIRNAME}/run-shellcheck.sh"

# shellcheck source=SCRIPTDIR/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/test-helpers/docker-stub.bash"

setup() {

    # shellcheck source=SCRIPTDIR/versions.env
    source "${BATS_TEST_DIRNAME}/versions.env"
    expected_image="koalaman/shellcheck:v${SHELLCHECK_VERSION}"

    install_docker_stub pull 'exit 0'
    install_cygpath_stub
}

@test "runs the pinned image over the current folder" {

    run --separate-stderr run_shellcheck --severity=style -- a.sh

    [ "${status}" -eq 0 ]
    [ "$(read_docker_run_arguments)" = "--rm
-v
C:/host${PWD}:/work
-w
/work
${expected_image}
--severity=style
--
a.sh" ]
}

# A native install is what drifted the version before, so it must go unused.
@test "runs the pinned image even when shellcheck is on PATH" {

    install_path_stub shellcheck <<STUB
#!/usr/bin/env bash
touch "${BATS_TEST_TMPDIR}/native-shellcheck-ran"
STUB

    run --separate-stderr run_shellcheck -- a.sh

    [ "${status}" -eq 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/native-shellcheck-ran" ]
    [[ "$(read_docker_run_arguments)" == *"${expected_image}"* ]]
}

@test "pulls the image when it is not cached" {

    run --separate-stderr run_shellcheck -- a.sh

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [[ "${stderr}" == *"Pulling ${expected_image}, the first run of this version here."* ]]
}

@test "skips the pull when the image is cached" {

    DOCKER_STUB_IMAGE_EXIT=0 run --separate-stderr run_shellcheck -- a.sh

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 0 ]
}

# A permanent failure is not retried, so the case needs no backoff settings.
@test "ends without linting when the pull fails for good" {

    install_docker_stub pull 'echo "Permission denied" >&2; exit 13'

    run --separate-stderr run_shellcheck -- a.sh

    [ "${status}" -eq 13 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [ -z "$(read_docker_run_arguments)" ]
}

@test "says on stderr which image runs over which folder" {

    DOCKER_STUB_IMAGE_EXIT=0 run --separate-stderr run_shellcheck -- a.sh

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "Running ${expected_image} over C:/host${PWD}." ]
}
