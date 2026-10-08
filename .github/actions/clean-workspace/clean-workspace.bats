#!/usr/bin/env bats
# Unit tests for clean-workspace.sh.
# Run with: bats .github/actions/clean-workspace/clean-workspace.bats
#
# The script's whole job is a recursive delete, so the refusals are tested as
# carefully as the delete itself.

SCRIPT="${BATS_TEST_DIRNAME}/clean-workspace.sh"

setup() {

    WORKSPACE="${BATS_TEST_TMPDIR}/workspace"
    export GITHUB_WORKSPACE="${WORKSPACE}"
}

@test "empties the workspace, dotfiles and nested trees included" {

    mkdir -p "${WORKSPACE}/sibling/.git" "${WORKSPACE}/build"
    touch "${WORKSPACE}/.stale" "${WORKSPACE}/build/output.zip"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -z "$(ls -A "${WORKSPACE}")" ]
}

@test "keeps the workspace directory itself" {

    # Later steps expect the directory the runner created to still be there.
    mkdir -p "${WORKSPACE}"
    touch "${WORKSPACE}/stale"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -d "${WORKSPACE}" ]
}

@test "names each entry in the log before deleting it" {

    mkdir -p "${WORKSPACE}/sibling"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${WORKSPACE}/sibling"* ]]
}

@test "leaves everything outside the workspace alone" {

    mkdir -p "${WORKSPACE}"
    touch "${WORKSPACE}/stale" "${BATS_TEST_TMPDIR}/neighbour"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -f "${BATS_TEST_TMPDIR}/neighbour" ]
}

@test "succeeds when the workspace does not exist yet" {

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"does not exist yet"* ]]
}

@test "refuses an unset workspace" {

    unset GITHUB_WORKSPACE

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"GITHUB_WORKSPACE is unset"* ]]
}

@test "refuses a relative workspace" {

    mkdir -p "${BATS_TEST_TMPDIR}/relative/kept"
    cd "${BATS_TEST_TMPDIR}"

    GITHUB_WORKSPACE="relative" run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not an absolute POSIX path"* ]]
    [ -d "${BATS_TEST_TMPDIR}/relative/kept" ]
}

@test "refuses a Windows-shaped workspace" {

    # What GITHUB_WORKSPACE looks like under Git Bash on a Windows runner.
    GITHUB_WORKSPACE='D:\a\repo\repo' run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"not an absolute POSIX path"* ]]
}

@test "refuses the filesystem root" {

    GITHUB_WORKSPACE="/" run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"is the filesystem root"* ]]
}
