#!/usr/bin/env bats
# Unit tests for shellcheck-hooks.sh - the strict-shellcheck wrapper for the
# extension-less files under .githooks/. The FLAGS array itself is gated by
# shellcheck-bash.bats; this file covers the hook-specific guards: missing
# dir, empty dir, and the happy path against a real fixture hook.
# Run with: bats actions/shellcheck-hooks/shellcheck-hooks.bats

SCRIPT="${BATS_TEST_DIRNAME}/shellcheck-hooks.sh"

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/git-fixtures.bash"

# Skips the calling test when shellcheck is not on PATH, for the cases that
# lint a real fixture. The script requires it natively: CI runners have it,
# while a Windows workstation lints through the docker image instead.
require_shellcheck() {

    command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not on PATH"
}

@test "missing hooks dir skips with exit 0" {

    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/no-such-dir"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"does not exist, skipping"* ]]
}

@test "empty hooks dir skips with exit 0" {

    empty_dir="${BATS_TEST_TMPDIR}/empty-hooks"
    mkdir -p "${empty_dir}"

    run "${SCRIPT}" "${empty_dir}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no files under"* ]]
}

@test "clean hook file lints successfully" {

    require_shellcheck
    hooks_dir="${BATS_TEST_TMPDIR}/hooks"
    mkdir -p "${hooks_dir}"

    cat > "${hooks_dir}/pre-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
    run "${SCRIPT}" "${hooks_dir}"

    [ "${status}" -eq 0 ]
}

@test "hook with shellcheck violation fails" {

    require_shellcheck
    hooks_dir="${BATS_TEST_TMPDIR}/bad-hooks"
    mkdir -p "${hooks_dir}"

    # Bare [ ] with unquoted variable trips SC2086 at strict severity.
    cat > "${hooks_dir}/pre-commit" <<'EOF'
#!/usr/bin/env bash
foo=$1
if [ -z $foo ]; then
    echo bad
fi
EOF
    run "${SCRIPT}" "${hooks_dir}"

    [ "${status}" -ne 0 ]
}

@test "skips a work tree whose hooks are all untracked" {

    require_git
    new_git_repo
    mkdir -p .githooks
    printf '#!/bin/sh\necho $1\n' > .githooks/post-commit

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no files under .githooks/, skipping"* ]]
}

@test "lints the tracked hooks and leaves an untracked one alone" {

    require_shellcheck
    require_git
    new_git_repo
    mkdir -p .githooks

    printf '#!/usr/bin/env bash\nset -euo pipefail\necho "ok"\n' > .githooks/pre-commit
    git add .githooks/pre-commit

    # Fails the strict bar if linted (SC2086), as graphify's local hooks do.
    printf '#!/bin/sh\necho $1\n' > .githooks/post-commit

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
}
