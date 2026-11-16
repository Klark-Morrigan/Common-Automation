#!/usr/bin/env bats
# Unit tests for test-bats.sh - the composite action's helper that runs the
# bats suites git tracks. bats is stubbed, so no case runs a real suite, and
# the cases that reach bats run on a PATH of stubs alone, so whether GNU
# parallel is there is the case's choice, not the host's.

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/git-fixtures.bash"

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/path-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/path-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/test-bats.sh"

setup() {

    require_git

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

# Writes an empty suite at each given path and stages it.
#   add_tracked_suites <path...>
add_tracked_suites() {

    local path

    for path in "$@"; do

        mkdir -p "$(dirname "${path}")"
        : > "${path}"
        git add -- "${path}"
    done
}

# Puts stand-ins for GNU parallel and nproc on PATH, nproc counting <cores>.
# Only parallel's presence matters, since the bats stub never calls it.
#   install_parallel_stub <cores>
install_parallel_stub() {

    install_path_stub parallel <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

    install_path_stub nproc <<STUB
#!/usr/bin/env bash
echo $1
STUB
}

# Runs test-bats.sh from the repo with the stubs as its whole PATH. The real
# commands are the ones it needs to start and to ask git for the suites.
#   run_test_bats_on_stub_path <argument...>
run_test_bats_on_stub_path() {

    local command_name

    for command_name in bash dirname git; do
        install_real_command "${command_name}"
    done

    (cd "${REPO}" && PATH="${BATS_TEST_TMPDIR}/path-stubs" "${SCRIPT}" "$@")
}

@test "fails naming the folder when it is not a git work tree" {

    local plain_dir="${BATS_TEST_TMPDIR}/plain"
    mkdir -p "${plain_dir}"
    : > "${plain_dir}/suite.bats"

    # The ceiling stops git finding a repo above the temp folder.
    run env GIT_CEILING_DIRECTORIES="${BATS_TEST_TMPDIR}" \
        bash -c "cd '${plain_dir}' && '${SCRIPT}' ."

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"::error::${plain_dir} is not a git work tree"* ]]
}

@test "skips with a notice, without running bats, when git tracks no suite under the path" {

    new_git_repo
    install_bats_stub 0

    # On disk but never added, so it is not one of the repo's suites.
    : > untracked.bats

    run run_test_bats_on_stub_path .

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"::notice::git tracks no bats suites under ., skipping"* ]]
    [ ! -f "${bats_arguments_file}" ]
}

@test "runs bats over the tracked suites alone, leaving out a nested checkout" {

    new_git_repo
    add_tracked_suites Tests/a.bats .github/actions/b/b.bats
    install_bats_stub 0

    git init -q .common-automation
    : > .common-automation/c.bats
    git -C .common-automation add c.bats

    run run_test_bats_on_stub_path .

    [ "${status}" -eq 0 ]
    [ "$(cat "${bats_arguments_file}")" = ".github/actions/b/b.bats
Tests/a.bats" ]
}

@test "spreads the suites over one job per core, each file whole, when GNU parallel is on PATH" {

    new_git_repo
    add_tracked_suites a.bats
    install_bats_stub 0
    install_parallel_stub 6

    run run_test_bats_on_stub_path .

    [ "${status}" -eq 0 ]
    [ "$(cat "${bats_arguments_file}")" = "--jobs
6
--no-parallelize-within-files
a.bats" ]
}

@test "runs the suites one at a time, with a notice, when GNU parallel is not on PATH" {

    new_git_repo
    add_tracked_suites a.bats
    install_bats_stub 0

    run run_test_bats_on_stub_path .

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"::notice::GNU parallel is not on PATH, so the suites run one at a time"* ]]
    [ "$(cat "${bats_arguments_file}")" = "a.bats" ]
}

@test "logs how many suites it runs, under which path, over how many jobs" {

    new_git_repo
    add_tracked_suites Tests/a.bats Tests/b.bats
    install_bats_stub 0
    install_parallel_stub 6

    run run_test_bats_on_stub_path Tests

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Running 2 suite(s) under Tests over 6 job(s)."* ]]
}

@test "logs that the suites run one at a time when GNU parallel is not on PATH" {

    new_git_repo
    add_tracked_suites Tests/a.bats
    install_bats_stub 0

    run run_test_bats_on_stub_path Tests

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Running 1 suite(s) under Tests one at a time."* ]]
}

@test "hands the bats options it is given to bats, after the job options and ahead of the suites" {

    new_git_repo
    add_tracked_suites a.bats
    install_bats_stub 0
    install_parallel_stub 6

    run run_test_bats_on_stub_path . --pretty

    [ "${status}" -eq 0 ]
    [ "$(cat "${bats_arguments_file}")" = "--jobs
6
--no-parallelize-within-files
--pretty
a.bats" ]
}

@test "exits with the status bats returns" {

    new_git_repo
    add_tracked_suites a.bats
    install_bats_stub 3

    run run_test_bats_on_stub_path .

    [ "${status}" -eq 3 ]
}
