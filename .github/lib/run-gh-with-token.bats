#!/usr/bin/env bats
# Unit tests for run-gh-with-token.sh.
# Run with: bats .github/lib/run-gh-with-token.bats
#
# gh is a stub that prints its arguments and the GH_TOKEN it was handed, so
# each case reads back what one gh process got.

# shellcheck source=SCRIPTDIR/test-helpers/path-stub.bash
source "${BATS_TEST_DIRNAME}/test-helpers/path-stub.bash"

# shellcheck source=SCRIPTDIR/run-gh-with-token.sh
source "${BATS_TEST_DIRNAME}/run-gh-with-token.sh"

setup() {

    install_path_stub gh <<'STUB'
#!/usr/bin/env bash
printf 'args: %s\n' "$*"
printf 'token: %s\n' "${GH_TOKEN-<unset>}"
exit "${GH_EXIT:-0}"
STUB

    unset GH_TOKEN GH_EXIT
}

@test "hands gh the token and its arguments" {

    run run_gh_with_token "test-token" api repos/owner/repo/releases

    [ "${status}" -eq 0 ]
    [ "${output}" = "args: api repos/owner/repo/releases
token: test-token" ]
}

@test "runs gh without a token when the token is empty, so gh's own login answers" {

    run run_gh_with_token "" api repos/owner/repo/releases

    [ "${status}" -eq 0 ]
    [ "${lines[1]}" = "token: <unset>" ]
}

@test "leaves GH_TOKEN unset in the caller's shell" {

    run_gh_with_token "test-token" api repos/owner/repo/releases > /dev/null

    [ -z "${GH_TOKEN+set}" ]
}

@test "returns gh's status" {

    export GH_EXIT=4

    run run_gh_with_token "test-token" api repos/owner/repo/releases

    [ "${status}" -eq 4 ]
}
