#!/usr/bin/env bats
# Unit tests for run-git-with-token.sh.
# Run with: bats .github/actions/publish-download-badges/badge-branch/run-git-with-token.bats
#
# git is a stub that writes its arguments and the environment config it was
# handed, so each case reads back what one git process got.

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/path-stub.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/path-stub.bash"

# shellcheck source=SCRIPTDIR/run-git-with-token.sh
source "${BATS_TEST_DIRNAME}/run-git-with-token.sh"

REMOTE_URL="https://github.com/owner/repo.git"
CREDENTIAL="dGVzdA=="

setup() {

    install_path_stub git <<'STUB'
#!/usr/bin/env bash
printf 'args: %s\n' "$*"
printf 'count: %s\n' "${GIT_CONFIG_COUNT:-}"
printf '%s=%s\n' "${GIT_CONFIG_KEY_0:-}" "${GIT_CONFIG_VALUE_0:-}"
printf '%s=%s\n' "${GIT_CONFIG_KEY_1:-}" "${GIT_CONFIG_VALUE_1:-}"
STUB

    unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
}

@test "hands git the header for the remote URL alone, and an empty credential helper" {

    run run_git_with_token "${REMOTE_URL}" "${CREDENTIAL}" ls-remote "${REMOTE_URL}" refs/heads/badges

    [ "${status}" -eq 0 ]
    [ "${output}" = "args: ls-remote ${REMOTE_URL} refs/heads/badges
count: 2
http.${REMOTE_URL}.extraheader=AUTHORIZATION: basic ${CREDENTIAL}
credential.helper=" ]
}

@test "keeps the credential off git's command line" {

    run run_git_with_token "${REMOTE_URL}" "${CREDENTIAL}" fetch -q "${REMOTE_URL}"

    [ "${status}" -eq 0 ]
    [[ "${lines[0]}" != *"${CREDENTIAL}"* ]]
}

@test "leaves no config behind in the caller's shell" {

    run_git_with_token "${REMOTE_URL}" "${CREDENTIAL}" ls-remote "${REMOTE_URL}" > /dev/null

    [ -z "${GIT_CONFIG_COUNT:-}" ]
    [ -z "${GIT_CONFIG_VALUE_0:-}" ]
}

@test "returns git's status" {

    install_path_stub git <<'STUB'
#!/usr/bin/env bash
exit 128
STUB

    run run_git_with_token "${REMOTE_URL}" "${CREDENTIAL}" push -q "${REMOTE_URL}"

    [ "${status}" -eq 128 ]
}
