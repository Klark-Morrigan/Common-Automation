#!/usr/bin/env bats
# Unit tests for test-bats.sh - the composite action's helper that runs the
# bats suites git tracks. bats is stubbed, so no case runs a real suite.

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

    run bash -c "cd '${REPO}' && '${SCRIPT}' ."

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

    run bash -c "cd '${REPO}' && '${SCRIPT}' ."

    [ "${status}" -eq 0 ]
    [ "$(cat "${bats_arguments_file}")" = ".github/actions/b/b.bats
Tests/a.bats" ]
}

@test "logs how many suites it runs and under which path" {

    new_git_repo
    add_tracked_suites Tests/a.bats Tests/b.bats
    install_bats_stub 0

    run bash -c "cd '${REPO}' && '${SCRIPT}' Tests"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Running 2 suite(s) under Tests."* ]]
}

@test "exits with the status bats returns" {

    new_git_repo
    add_tracked_suites a.bats
    install_bats_stub 3

    run bash -c "cd '${REPO}' && '${SCRIPT}' ."

    [ "${status}" -eq 3 ]
}
