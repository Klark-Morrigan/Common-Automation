#!/usr/bin/env bats
# Unit tests for list-hook-files.sh.
# Run with: bats .github/lib/list-hook-files.bats

# shellcheck source=SCRIPTDIR/list-hook-files.sh
source "${BATS_TEST_DIRNAME}/list-hook-files.sh"

# shellcheck source=SCRIPTDIR/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/test-helpers/git-fixtures.bash"

# Writes an empty file at each given path, creating its folder.
#   write_files <path...>
write_files() {

    local path

    for path in "$@"; do

        mkdir -p "${path%/*}"
        : > "${path}"
    done
}

@test "lists every top-level file outside a work tree, sorted" {

    local hooks_dir="${BATS_TEST_TMPDIR}/loose/hooks"
    write_files "${hooks_dir}/pre-push" "${hooks_dir}/pre-commit"

    run list_hook_files "${hooks_dir}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${hooks_dir}/pre-commit
${hooks_dir}/pre-push" ]
}

@test "leaves out dotfiles and files in subfolders" {

    local hooks_dir="${BATS_TEST_TMPDIR}/loose/hooks"
    write_files "${hooks_dir}/pre-commit" "${hooks_dir}/.gitignore" "${hooks_dir}/lib/helper"

    run list_hook_files "${hooks_dir}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${hooks_dir}/pre-commit" ]
}

@test "lists the tracked files alone in a work tree" {

    require_git
    new_git_repo
    write_files .githooks/pre-commit .githooks/post-commit .githooks/.gitignore
    git add .githooks/pre-commit .githooks/.gitignore

    run list_hook_files .githooks

    [ "${status}" -eq 0 ]
    [ "${output}" = ".githooks/pre-commit" ]
}

@test "prints nothing for a directory holding no hook file" {

    local hooks_dir="${BATS_TEST_TMPDIR}/loose/hooks"
    mkdir -p "${hooks_dir}"

    run list_hook_files "${hooks_dir}"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
