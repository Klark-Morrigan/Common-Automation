#!/usr/bin/env bats
# Unit tests for _run-tests-bash.sh, the test half of the local CI suite.
# Run with: bats scripts/_run-tests-bash.bats
#
# bats and docker are stubbed, every case runs on a PATH of stubs alone so
# the host's own tools are out of reach, and COMMON_AUTOMATION_TARGET_REPO points the
# runner at a throwaway git repo whose suites are empty files, so no case
# runs a real suite.

SCRIPT="${BATS_TEST_DIRNAME}/_run-tests-bash.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/docker-stub.bash"

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo
    export COMMON_AUTOMATION_TARGET_REPO="${REPO}"

    stub_dir="${BATS_TEST_TMPDIR}/path-stubs"
    bats_arguments_file="${BATS_TEST_TMPDIR}/bats-arguments"
}

# Adds an empty suite at each path, tracked by git.
#   add_tracked_suites <path...>
add_tracked_suites() {

    local suite

    for suite in "$@"; do
        mkdir -p "$(dirname "${suite}")"
        : > "${suite}"
    done

    git add -- "$@"
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
# start, find the suites, and fetch the image through the retry primitive.
#   run_runner_on_stub_path
run_runner_on_stub_path() {

    local command_name

    for command_name in bash cat cksum date dirname git mktemp rm tee; do
        install_real_command "${command_name}"
    done

    PATH="${stub_dir}" "${SCRIPT}"
}

@test "runs in the pinned image, never a bats on PATH" {

    add_tracked_suites top.bats
    install_bats_stub 0
    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [ ! -e "${bats_arguments_file}" ]
    [[ "$(read_docker_run_arguments)" == *"/code/top.bats" ]]
    [[ "${output}" == *"Bash tests passed."* ]]
}

@test "leaves out a suite git does not track, naming it" {

    add_tracked_suites tracked.bats
    : > untracked.bats
    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *"--no-parallelize-within-files
/code/tracked.bats" ]]
    [[ "${output}" == *"git does not track: untracked.bats."* ]]
}

@test "skips, saying so, when git tracks no suite" {

    install_docker_stub build 'exit 0'

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"git tracks no bats suites, skipping."* ]]
    [ -z "$(read_docker_run_arguments)" ]
}

@test "fails, naming the folder, when the target is not a git work tree" {

    export COMMON_AUTOMATION_TARGET_REPO="${BATS_TEST_TMPDIR}/plain"
    mkdir -p "${COMMON_AUTOMATION_TARGET_REPO}"
    install_docker_stub build 'exit 0'

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"${COMMON_AUTOMATION_TARGET_REPO} is not a git work tree"* ]]
    [ -z "$(read_docker_run_arguments)" ]
}

@test "fails, saying so, when the suites fail" {

    add_tracked_suites top.bats
    install_docker_stub build 'exit 0'
    install_cygpath_stub
    export DOCKER_STUB_RUN_EXIT=1

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [ "$(sed -n '/^FAILED/,$p' <<< "${output}")" = "FAILED (bash tests):
  bats" ]
}

@test "builds the image of the pinned bats once, tagged with the pin" {

    local bats_version

    bats_version="$("${BATS_TEST_DIRNAME}/../.github/lib/get-tool-version.sh" BATS_VERSION)"
    add_tracked_suites top.bats
    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [[ "$(read_docker_run_arguments)" == *"common-automation/bats:${bats_version}-"* ]]
}

@test "runs the tracked suites offline over the target's host path, mounted read-only" {

    add_tracked_suites top.bats nested/inner.bats
    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run run_runner_on_stub_path

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *"--network
none"* ]]
    [[ "$(read_docker_run_arguments)" == *"C:/host${COMMON_AUTOMATION_TARGET_REPO}:/code:ro"* ]]
    [[ "$(read_docker_run_arguments)" == *"--no-parallelize-within-files
/code/nested/inner.bats
/code/top.bats" ]]
}

@test "spreads the suites over one job per host core" {

    add_tracked_suites top.bats
    install_docker_stub build 'exit 0'
    install_cygpath_stub
    install_path_stub nproc <<'STUB'
#!/usr/bin/env bash
echo 6
STUB

    run run_runner_on_stub_path

    [[ "$(read_docker_run_arguments)" == *"--jobs
6
"* ]]
}

@test "runs one job when the host cannot count its cores" {

    add_tracked_suites top.bats
    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run run_runner_on_stub_path

    [[ "$(read_docker_run_arguments)" == *"--jobs
1
"* ]]
}

@test "fails, naming docker, when docker is not on PATH, though a bats is" {

    add_tracked_suites top.bats
    install_bats_stub 0

    run run_runner_on_stub_path

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Docker is not available"* ]]
    [ ! -e "${bats_arguments_file}" ]
}
