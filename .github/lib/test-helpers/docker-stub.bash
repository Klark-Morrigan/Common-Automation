#!/usr/bin/env bash
# Shared docker stub for the bats suites of the lint actions that fetch their
# image through retry.sh - one docker verb (pull or build) retried, then
# `docker run`. Sourced - never run - so it carries no tests itself and is
# skipped by the recursive *.bats runner.

# shellcheck source=SCRIPTDIR/path-stub.bash
source "${BASH_SOURCE[0]%/*}/path-stub.bash"

# shellcheck source=SCRIPTDIR/require-command.bash
source "${BASH_SOURCE[0]%/*}/require-command.bash"

# Skips the calling test when no docker engine is reachable, for the cases
# that lint real fixtures through the real image.
require_docker() {

    require_command docker
    docker info > /dev/null 2>&1 || skip "docker daemon not running"
}

# Puts a docker stub first on PATH. The stub:
#   - answers `image inspect` with DOCKER_STUB_IMAGE_EXIT, default 1, so the
#     script fetches the image unless a case says it is cached;
#   - counts each call of <retried verb> in ${DOCKER_ATTEMPTS_FILE} and runs
#     <body> for it, with the attempt number in DOCKER_ATTEMPT, so a case
#     decides success, transient failure or permanent failure per attempt;
#   - records the arguments of `docker run`, one per line, and succeeds, so
#     it lints nothing but a case can check what it was handed;
#   - succeeds every other verb quietly.
#   install_docker_stub <retried verb> <body>
install_docker_stub() {

    local retried_verb="${1:?install_docker_stub: retried verb required}"
    local body_file="${BATS_TEST_TMPDIR}/docker-stub-body.sh"

    export DOCKER_ATTEMPTS_FILE="${BATS_TEST_TMPDIR}/docker-attempts"
    export DOCKER_RUN_ARGUMENTS_FILE="${BATS_TEST_TMPDIR}/docker-run-arguments"

    printf '%s\n' "${2:?install_docker_stub: body required}" > "${body_file}"

    install_path_stub docker <<STUB
#!/usr/bin/env bash
case "\$1" in
    image)
        exit "\${DOCKER_STUB_IMAGE_EXIT:-1}"
        ;;
    ${retried_verb})
        DOCKER_ATTEMPT=\$(( \$(cat "${DOCKER_ATTEMPTS_FILE}" 2> /dev/null || echo 0) + 1 ))
        echo "\${DOCKER_ATTEMPT}" > "${DOCKER_ATTEMPTS_FILE}"
        source "${body_file}"
        ;;
    run)
        printf '%s\n' "\${@:2}" > "${DOCKER_RUN_ARGUMENTS_FILE}"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
STUB
}

# Puts a cygpath stub first on PATH that answers every path with a C:/host
# prefix, so a case can tell the docker host path from the path it came from
# on any OS.
install_cygpath_stub() {

    install_path_stub cygpath <<'STUB'
#!/usr/bin/env bash
printf 'C:/host%s\n' "$2"
STUB
}

# Prints the arguments the stub's `docker run` was handed, one per line.
read_docker_run_arguments() {

    cat "${DOCKER_RUN_ARGUMENTS_FILE}" 2> /dev/null
}

# Prints how many times the stub's retried verb was called.
count_docker_attempts() {

    cat "${DOCKER_ATTEMPTS_FILE}" 2> /dev/null || echo 0
}
