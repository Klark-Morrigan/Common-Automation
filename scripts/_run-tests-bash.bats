#!/usr/bin/env bats
# Unit tests for _run-tests-bash.sh, the test half of the local CI suite.
# Run with: bats scripts/_run-tests-bash.bats
#
# bats and docker are stubbed, and COMMON_AUTOMATION_TARGET_REPO points the
# runner at an empty folder, so no case runs a real suite.

SCRIPT="${BATS_TEST_DIRNAME}/_run-tests-bash.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/docker-stub.bash"

setup() {

    export COMMON_AUTOMATION_TARGET_REPO="${BATS_TEST_TMPDIR}/target"
    mkdir -p "${COMMON_AUTOMATION_TARGET_REPO}"

    stub_dir="${BATS_TEST_TMPDIR}/path-stubs"
    bats_arguments_file="${BATS_TEST_TMPDIR}/bats-arguments"
}

# Puts a bats stub on PATH that records its arguments, one per line, and
# exits with the given status.
#   install_bats_stub <exit status>
install_bats_stub() {

    install_path_stub bats <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "${bats_arguments_file}"
exit $1
STUB
}

# Runs the runner with the stubs as its whole PATH, so the host's own bats
# and docker are out of reach. bash and dirname are the tools it needs to
# start.
#   run_runner_on_stub_path
run_runner_on_stub_path() {

    install_real_command bash
    install_real_command dirname

    PATH="${stub_dir}" "${SCRIPT}"
}

@test "runs the native bats over the target repo, recursively" {

    install_bats_stub 0

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${bats_arguments_file}")" = "--pretty
--recursive
${COMMON_AUTOMATION_TARGET_REPO}" ]
    [[ "${output}" == *"Bash tests passed."* ]]
}

@test "fails, saying so, when the suites fail" {

    install_bats_stub 1

    run "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"FAILED (bats): bats"* ]]
}

@test "runs the pinned bats image over the target's host path when bats is not on PATH" {

    local bats_version

    bats_version="$("${BATS_TEST_DIRNAME}/../.github/lib/get-bats-version.sh")"
    install_docker_stub pull 'exit 0'
    install_cygpath_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *"C:/host${COMMON_AUTOMATION_TARGET_REPO}:/code"* ]]
    [[ "$(read_docker_run_arguments)" == *"bats/bats:${bats_version}"* ]]
}

@test "fails, naming both tools, when neither bats nor docker is on PATH" {

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Neither bats nor docker is available"* ]]
}
