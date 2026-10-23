#!/usr/bin/env bats
# Unit tests for _run-lint-yaml-and-bash.sh, the lint half of the local CI
# suite.
# Run with: bats scripts/_run-lint-yaml-and-bash.bats
#
# COMMON_AUTOMATION_TARGET_REPO points the runner at an empty git repo, where
# every check finds nothing to lint and skips, so no case needs shellcheck,
# docker or a linter image. Each helper's own suite covers what it lints.

SCRIPT="${BATS_TEST_DIRNAME}/_run-lint-yaml-and-bash.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../.github/lib/test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo
    export COMMON_AUTOMATION_TARGET_REPO="${REPO}"
}

@test "runs every check under its heading, in order, and passes when none fails" {

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(grep '^===' <<< "${output}")" = "=== shellcheck production (.github) ===
=== shellcheck runners (scripts) ===
=== shellcheck domain (.) ===
=== shellcheck hooks (.githooks) ===
=== check-sh-executable ===
=== actionlint ===
=== action-validator ===
=== yamllint ===" ]
    [[ "${output}" == *"Lint checks passed."* ]]
}

@test "runs every check after one fails, then names the failed one" {

    # Under Tests/, so the domain shellcheck leaves it alone and only the +x
    # gate sees it.
    mkdir Tests
    add_tracked_sh Tests/helper.sh -x

    run "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"=== yamllint ==="* ]]
    [[ "${output}" == *"FAILED (lint): check-sh-executable"* ]]
}
