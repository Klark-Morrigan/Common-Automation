#!/usr/bin/env bats
# Unit tests for create-masked-basic-credential.sh.
# Run with: bats .github/lib/create-masked-basic-credential.bats
#
# is_running_in_github_actions is replaced per case, after the file is
# sourced, so each case picks the runner it stands in.

# shellcheck source=SCRIPTDIR/create-masked-basic-credential.sh
source "${BATS_TEST_DIRNAME}/create-masked-basic-credential.sh"

# "x-access-token:test-token" in base64.
EXPECTED_CREDENTIAL="eC1hY2Nlc3MtdG9rZW46dGVzdC10b2tlbg=="

# Stands in for a run under GitHub Actions.
stand_in_github_actions() {

    is_running_in_github_actions() {

        return 0
    }
}

# Stands in for a run outside GitHub Actions.
stand_in_terminal() {

    is_running_in_github_actions() {

        return 1
    }
}

@test "encodes the token as GitHub's Basic credential, on one line" {

    stand_in_terminal

    create_masked_basic_credential "test-token" > /dev/null

    [ "${basic_credential}" = "${EXPECTED_CREDENTIAL}" ]
}

@test "under GitHub Actions, masks the credential" {

    stand_in_github_actions

    run create_masked_basic_credential "test-token"

    [ "${status}" -eq 0 ]
    [ "${output}" = "::add-mask::${EXPECTED_CREDENTIAL}" ]
}

# A local run would otherwise write the credential to the terminal.
@test "outside GitHub Actions, prints nothing" {

    stand_in_terminal

    run create_masked_basic_credential "test-token"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
