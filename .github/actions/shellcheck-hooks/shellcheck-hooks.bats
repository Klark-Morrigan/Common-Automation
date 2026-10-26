#!/usr/bin/env bats
# Unit tests for shellcheck-hooks.sh - the strict-shellcheck wrapper for the
# extension-less files under .githooks/. The FLAGS array itself is gated by
# shellcheck-bash.bats, and which files count as hooks by list-hook-files.bats;
# this file covers the skips and the lint of real fixture hooks.
# Run with: bats .github/actions/shellcheck-hooks/shellcheck-hooks.bats

SCRIPT="${BATS_TEST_DIRNAME}/shellcheck-hooks.sh"

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/docker-stub.bash"

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/git-fixtures.bash"

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

# The hooks folder is named relative to the working folder, the only one the
# pinned image has mounted.
@test "clean hook file lints successfully" {

    require_docker
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p hooks

    cat > hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ok"
EOF
    run "${SCRIPT}" hooks

    [ "${status}" -eq 0 ]
}

@test "hook with shellcheck violation fails" {

    require_docker
    cd "${BATS_TEST_TMPDIR}"
    mkdir -p bad-hooks

    # Bare [ ] with unquoted variable trips SC2086 at strict severity.
    cat > bad-hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
foo=$1
if [ -z $foo ]; then
    echo bad
fi
EOF
    run "${SCRIPT}" bad-hooks

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"SC2086"* ]]
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

    require_docker
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
