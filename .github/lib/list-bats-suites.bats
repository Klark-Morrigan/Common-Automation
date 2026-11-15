#!/usr/bin/env bats
# Unit tests for list-bats-suites.sh.
# Run with: bats .github/lib/list-bats-suites.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/list-bats-suites.sh
source "${BATS_TEST_DIRNAME}/list-bats-suites.sh"

# shellcheck source=SCRIPTDIR/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo
}

# Writes an empty file at each given path, creating its folder.
#   write_files <path...>
write_files() {

    local path

    for path in "$@"; do

        mkdir -p "$(dirname "${path}")"
        : > "${path}"
    done
}

@test "lists the tracked suites at every depth, sorted" {

    write_files top.bats Tests/unit/deep.bats .github/actions/a/a.bats
    git add top.bats Tests/unit/deep.bats .github/actions/a/a.bats

    run --separate-stderr list_bats_suites .

    [ "${status}" -eq 0 ]
    [ "${output}" = ".github/actions/a/a.bats
Tests/unit/deep.bats
top.bats" ]
}

@test "lists only the suites under the given directory" {

    write_files Tests/inside.bats outside.bats
    git add Tests/inside.bats outside.bats

    run --separate-stderr list_bats_suites Tests

    [ "${status}" -eq 0 ]
    [ "${output}" = "Tests/inside.bats" ]
}

@test "leaves out files that are not suites" {

    write_files Tests/suite.bats Tests/helpers.bash Tests/script.sh
    git add Tests

    run --separate-stderr list_bats_suites .

    [ "${status}" -eq 0 ]
    [ "${output}" = "Tests/suite.bats" ]
}

@test "leaves out the suites of a nested checkout" {

    write_files own.bats
    git add own.bats

    # Stands in for the .common-automation checkout CI stages in a consumer.
    git init -q .common-automation
    write_files .common-automation/.github/actions/a/a.bats
    git -C .common-automation add .github/actions/a/a.bats

    run --separate-stderr list_bats_suites .

    [ "${status}" -eq 0 ]
    [ "${output}" = "own.bats" ]
    [ -z "${stderr}" ]
}

@test "names the untracked suites it leaves out, on stderr alone" {

    write_files tracked.bats forgotten.bats Tests/new.bats
    git add tracked.bats

    run --separate-stderr list_bats_suites .

    [ "${status}" -eq 0 ]
    [ "${output}" = "tracked.bats" ]
    [ "${stderr}" = "Leaving out the suites under . that git does not track: Tests/new.bats, forgotten.bats." ]
}

@test "leaves out a tracked suite deleted from disk" {

    write_files kept.bats removed.bats
    git add kept.bats removed.bats
    rm removed.bats

    run --separate-stderr list_bats_suites .

    [ "${status}" -eq 0 ]
    [ "${output}" = "kept.bats" ]
}

@test "prints nothing for a directory holding no suite" {

    write_files README.md
    git add README.md

    run --separate-stderr list_bats_suites .

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ -z "${stderr}" ]
}
