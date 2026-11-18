#!/usr/bin/env bats
# Unit tests for _run-tests-bash.sh, the test half of the local CI suite.
# Run with: bats scripts/_run-tests-bash.bats
#
# docker is stubbed and every case runs on a PATH of stubs alone, so the
# host's own bats and docker are out of reach and no case runs a real suite.
# Which suites run is test-bats.sh's part, covered by its own suite.

SCRIPT="${BATS_TEST_DIRNAME}/_run-tests-bash.sh"

COMMON_AUTOMATION_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/docker-stub.bash"

setup() {

    export CONSUMER_REPO_PATH="${BATS_TEST_TMPDIR}/consumer"
    mkdir -p "${CONSUMER_REPO_PATH}"

    stub_dir="${BATS_TEST_TMPDIR}/path-stubs"
    bats_arguments_file="${BATS_TEST_TMPDIR}/bats-arguments"
    build_arguments_file="${BATS_TEST_TMPDIR}/build-arguments"
}

# Puts a docker stub on PATH whose build records its arguments, one per line,
# and succeeds.
#   install_recording_docker_stub
install_recording_docker_stub() {

    install_docker_stub build "printf '%s\n' \"\$@\" > '${build_arguments_file}'"
    install_cygpath_stub
}

# Succeeds when the stub's `docker run` was handed <argument> as one whole
# argument.
#   has_docker_run_argument <argument>
has_docker_run_argument() {

    grep -Fxq -- "$1" <<< "$(read_docker_run_arguments)"
}

# Prints the image the stub's `docker run` was handed: the argument before
# the command it runs.
#   read_run_image
read_run_image() {

    grep -B 1 -Fx bash <<< "$(read_docker_run_arguments)" | head -n 1
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
# and docker are out of reach. The real commands are the ones it needs to
# start, fetch the image through the retry primitive, and clear stale tags.
#   run_runner_on_stub_path
run_runner_on_stub_path() {

    local command_name

    for command_name in bash cat cksum date dirname mktemp rm tee; do
        install_real_command "${command_name}"
    done

    PATH="${stub_dir}" "${SCRIPT}"
}

@test "runs CI's test-bats.sh over the consumer in the pinned image, never a bats on PATH" {

    install_bats_stub 0
    install_recording_docker_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [ ! -e "${bats_arguments_file}" ]
    [[ "$(read_docker_run_arguments)" == *"-w
/code
"*"
bash
/common-automation/.github/actions/test-bats/test-bats.sh
.
--pretty" ]]
    [[ "${output}" == *"Bash tests passed."* ]]
}

@test "runs offline over read-only mounts of the consumer and of Common-Automation's .github" {

    install_recording_docker_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *"--network
none"* ]]
    has_docker_run_argument "C:/host${CONSUMER_REPO_PATH}:/code:ro"
    has_docker_run_argument "C:/host${COMMON_AUTOMATION_ROOT}/.github:/common-automation/.github:ro"
}

@test "mounts a consumer whose path holds a space as one argument" {

    export CONSUMER_REPO_PATH="${BATS_TEST_TMPDIR}/consumer repo"
    mkdir -p "${CONSUMER_REPO_PATH}"
    install_recording_docker_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    has_docker_run_argument "C:/host${CONSUMER_REPO_PATH}:/code:ro"
}

@test "logs the consumer, where it is mounted, and the image" {

    local consumer="${CONSUMER_REPO_PATH}"

    install_recording_docker_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Running the suites of ${consumer}, mounted at /code, in $(read_run_image)."* ]]
}

@test "builds the image once from the test-bats folder, with the pinned version" {

    local bats_version
    local build_arguments=()

    bats_version="$("${BATS_TEST_DIRNAME}/../.github/lib/get-tool-version.sh" BATS_VERSION)"
    install_recording_docker_stub

    run run_runner_on_stub_path

    mapfile -t build_arguments < "${build_arguments_file}"

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [ "${build_arguments[0]}" = "build" ]
    [ "${build_arguments[1]}" = "--build-arg" ]
    [ "${build_arguments[2]}" = "VERSION=${bats_version}" ]
    [ "${build_arguments[3]}" = "-t" ]
    [ "${build_arguments[5]}" = "${COMMON_AUTOMATION_ROOT}/.github/actions/test-bats" ]
}

@test "tags the image with the pin and the Dockerfile's checksum, and runs that tag" {

    local bats_version
    local build_arguments=()

    bats_version="$("${BATS_TEST_DIRNAME}/../.github/lib/get-tool-version.sh" BATS_VERSION)"
    install_recording_docker_stub

    run run_runner_on_stub_path

    mapfile -t build_arguments < "${build_arguments_file}"

    # cksum prints a decimal checksum.
    local tag_pattern="^common-automation/bats:${bats_version}-[0-9]+$"

    [ "${status}" -eq 0 ]
    [[ "${build_arguments[4]}" =~ ${tag_pattern} ]]
    [ "$(read_run_image)" = "${build_arguments[4]}" ]
}

@test "skips the build when the image is cached" {

    install_recording_docker_stub
    export DOCKER_STUB_IMAGE_EXIT=0

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 0 ]
    [[ "$(read_run_image)" == "common-automation/bats:"* ]]
}

@test "removes the other tags of the bats image, keeping the one it runs" {

    local current_image

    install_recording_docker_stub

    run run_runner_on_stub_path

    current_image="$(read_run_image)"
    export DOCKER_STUB_IMAGE_EXIT=0
    export DOCKER_STUB_IMAGE_LIST="common-automation/bats:1.0.0-1
${current_image}
common-automation/bats:1.0.0-2
"

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [ "$(read_docker_image_removals)" = "common-automation/bats:1.0.0-1
common-automation/bats:1.0.0-2" ]
    [[ "${output}" == *"Removing the stale common-automation/bats:1.0.0-1."* ]]
}

@test "fails the check and still reports the summary when every build attempt fails" {

    install_docker_stub build 'echo "Permission denied" >&2; exit 13'
    install_cygpath_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [ -z "$(read_docker_run_arguments)" ]
    [[ "${output}" == *"bats FAILED in "* ]]
    [ "$(sed -n '/^FAILED/,$p' <<< "${output}")" = "FAILED (bash tests):
  bats" ]
}

@test "fails, saying so, when the suites fail" {

    install_recording_docker_stub
    export DOCKER_STUB_RUN_EXIT=1

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [ "$(sed -n '/^FAILED/,$p' <<< "${output}")" = "FAILED (bash tests):
  bats" ]
}

@test "fails, saying so, when the docker daemon is not running" {

    install_recording_docker_stub
    export DOCKER_STUB_INFO_EXIT=1

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Docker CLI is installed but the daemon is not running."* ]]
    [ "$(count_docker_attempts)" -eq 0 ]
    [ -z "$(read_docker_run_arguments)" ]
}

@test "fails, naming docker, when docker is not on PATH, though a bats is" {

    install_bats_stub 0

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Docker is not available"* ]]
    [ ! -e "${bats_arguments_file}" ]
}
