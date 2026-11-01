#!/usr/bin/env bats
# Unit tests for markdownlint.sh - the composite action's helper that lints
# the Markdown git tracks against the repo's own root config. The branches
# before the image is fetched (no work tree, nothing tracked, no config)
# and the docker argument list run against a stubbed docker, so they stay
# green on any workstation. Pass/fail outcomes run through the pinned image
# against the real family ruleset, and `skip` cleanly without an engine.

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/docker-stub.bash"

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/git-fixtures.bash"

SCRIPT="${BATS_TEST_DIRNAME}/markdownlint.sh"

setup() {

    require_git

    # Physical, as the script resolves it, so the expected mount matches.
    common_automation_dir="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
    version="$("${common_automation_dir}/.github/lib/get-tool-version.sh" MARKDOWNLINT_CLI2_VERSION)"
}

# Creates a git repo holding the consumer one-liner config, so a case starts
# past the skip and missing-config branches.
new_configured_repo() {

    new_git_repo
    printf '{ "extends": "../Common-Automation/.markdownlint.jsonc" }\n' > .markdownlint.jsonc
}

# Writes a Markdown file with the given content and stages it.
#   add_tracked_markdown <name> <content>
add_tracked_markdown() {

    printf '%s' "$2" > "$1"
    git add -- "$1"
}

@test "fails naming the folder when it is not a git work tree" {

    local plain_dir="${BATS_TEST_TMPDIR}/plain"
    mkdir -p "${plain_dir}"
    printf '# Title\n' > "${plain_dir}/README.md"

    # The ceiling stops git finding a repo above the temp folder.
    run env GIT_CEILING_DIRECTORIES="${BATS_TEST_TMPDIR}" \
        bash -c "cd '${plain_dir}' && '${SCRIPT}'"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"::error::${plain_dir} is not a git work tree"* ]]
}

@test "skips silently when git tracks no Markdown" {

    new_git_repo

    # On disk but never added, so it is not part of the authored surface.
    printf '# Title\n' > README.md

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"::notice::git tracks no Markdown files, skipping"* ]]
}

@test "skips silently when every tracked Markdown file is deleted from the work tree" {

    new_git_repo
    add_tracked_markdown README.md $'# Title\n'
    rm README.md

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping"* ]]
}

@test "fails naming the one-line config when the root config is missing" {

    new_git_repo
    add_tracked_markdown README.md $'# Title\n'

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"::error::no .markdownlint.jsonc at the root of ${REPO}"* ]]
    [[ "${output}" == *'{ "extends": "../Common-Automation/.markdownlint.jsonc" }'* ]]
}

@test "mounts the repo beside Common-Automation, read-only and offline, and passes files literally" {

    new_configured_repo
    add_tracked_markdown 'notes[1].md' $'# Notes\n'
    add_tracked_markdown README.md $'# Title\n'

    install_docker_stub pull 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [ "$(read_docker_run_arguments)" = "--rm
--network
none
-v
C:/host${REPO}:/src/repo:ro
-v
C:/host${common_automation_dir}:/src/Common-Automation:ro
-w
/src/repo
davidanson/markdownlint-cli2:v${version}
--
README.md
notes[1].md" ]
}

@test "leaves out a tracked file deleted from the work tree" {

    new_configured_repo
    add_tracked_markdown README.md $'# Title\n'
    add_tracked_markdown removed.md $'# Removed\n'
    rm removed.md

    install_docker_stub pull 'exit 0'

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *$'--\nREADME.md' ]]
}

@test "mounts Common-Automation once, at its sibling path, when it lints itself" {

    install_docker_stub pull 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${common_automation_dir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *$'-v\n'"C:/host${common_automation_dir}:/src/Common-Automation:ro"$'\n-w\n/src/Common-Automation\n'* ]]
    [[ "$(read_docker_run_arguments)" != *"/src/repo"* ]]
}

@test "logs how many files it lints and the folder it mounts" {

    new_configured_repo
    add_tracked_markdown README.md $'# Title\n'

    install_docker_stub pull 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Linting 1 file(s) in C:/host${REPO}."* ]]
}

@test "retry: transient docker pull failure recovers on second attempt" {

    new_configured_repo
    add_tracked_markdown README.md $'# Title\n'
    install_docker_stub pull 'if (( DOCKER_ATTEMPT < 2 )); then echo "dial tcp 1.2.3.4:443: i/o timeout" >&2; exit 1; fi; exit 0'

    run env \
        RETRY_MAX_ATTEMPTS=3 RETRY_BACKOFF_INITIAL_SECONDS=0 \
        RETRY_BACKOFF_JITTER_RATIO=0 \
        bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 2 ]
    [[ "${output}" == *"retriable via classify_docker_registry"* ]]
}

@test "retry: permanent docker pull failure exits immediately" {

    new_configured_repo
    add_tracked_markdown README.md $'# Title\n'
    install_docker_stub pull 'echo "Permission denied" >&2; exit 13'

    run env \
        RETRY_MAX_ATTEMPTS=5 RETRY_BACKOFF_INITIAL_SECONDS=0 \
        RETRY_BACKOFF_JITTER_RATIO=0 \
        bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 13 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [[ "${output}" == *"permanent (exit 13)"* ]]
    [[ "${output}" == *"::error::markdownlint: could not pull "* ]]
}

@test "retry: cached image (inspect hit) skips pull entirely" {

    new_configured_repo
    add_tracked_markdown README.md $'# Title\n'
    install_docker_stub pull 'exit 0'

    run env DOCKER_STUB_IMAGE_EXIT=0 \
        bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 0 ]
}

@test "exits 0 on Markdown that passes the family ruleset" {

    require_docker

    new_configured_repo
    add_tracked_markdown README.md $'# Title\n\nOne paragraph.\n'

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
}

@test "exits non-zero on a skipped heading level" {

    require_docker

    # MD001 is on in the family ruleset and stable across versions.
    new_configured_repo
    add_tracked_markdown README.md $'# Title\n\n### Skipped\n'

    run bash -c "cd '${REPO}' && '${SCRIPT}'"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"MD001"* ]]
}
