#!/usr/bin/env bats
# Unit tests for action-validator.sh - the composite action's helper
# that schema-validates workflows AND composite action.yml files. The
# most important contract is the skip-silently branch when nothing is
# discoverable (covered without docker so it stays green on any
# workstation), plus the pass/fail outcomes on real fixtures (covered
# through the locally-built common-automation/action-validator image so the
# bar matches what consumers actually experience). Docker-dependent
# tests `skip` cleanly when the engine is unavailable so the suite
# remains usable without it.

# shellcheck source=../../lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/docker-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/action-validator.sh"

setup() {

    # Run each case from an isolated workdir so the fixture trees
    # cannot leak across tests and so PWD-based file discovery in the
    # script sees only what the test created.
    workdir="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "${workdir}"
}

@test "skips silently when neither workflows nor actions directory exists" {

    # Pre-image-resolution branch - no docker required, so this test
    # locks the no-op contract even on bare workstations.

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping"* ]]
}

@test "exits 0 on a valid composite action.yml fixture" {

    require_docker
    mkdir -p "${workdir}/.github/actions/sample"

    cat > "${workdir}/.github/actions/sample/action.yml" <<'YAML'
name: sample
description: sample composite action
runs:
  using: composite
  steps:
    - name: echo
      shell: bash
      run: echo hello
YAML

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
}

@test "exits non-zero on a composite action.yml with a schema violation" {

    require_docker
    mkdir -p "${workdir}/.github/actions/broken"

    # `runs.using: bogus` is not in the schema's enum of allowed
    # runtimes - a stable failure-path fixture across action-validator
    # versions.
    cat > "${workdir}/.github/actions/broken/action.yml" <<'YAML'
name: broken
description: broken composite action
runs:
  using: bogus
  steps:
    - name: echo
      shell: bash
      run: echo hello
YAML

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -ne 0 ]
}

seed_minimal_workflow_repo() {

    # Bypass the auto-skip branch so the retry / build / run pipeline
    # is exercised. Content is irrelevant - the docker run is stubbed.
    mkdir -p "${workdir}/.github/workflows"
    printf 'name: w\non: push\njobs: {}\n' > "${workdir}/.github/workflows/w.yml"
}

@test "retry: docker build succeeds first try -> exit 0, no retry diagnostic" {

    seed_minimal_workflow_repo
    install_docker_stub build 'exit 0'

    run env \
        RETRY_MAX_ATTEMPTS=3 RETRY_BACKOFF_INITIAL_SECONDS=0 \
        RETRY_BACKOFF_JITTER_RATIO=0 \
        bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [[ "${output}" != *"retry: action-validator docker build attempt"* ]]
}

@test "retry: transient docker build failure recovers on second attempt" {

    seed_minimal_workflow_repo

    # First attempt prints a default-classifier-matching signature and
    # fails; second attempt succeeds. Default classifiers (docker /
    # network / 5xx) are active, so the dial-tcp message is treated as
    # transient and the primitive retries.
    install_docker_stub build 'if (( DOCKER_ATTEMPT < 2 )); then echo "dial tcp 1.2.3.4:443: i/o timeout" >&2; exit 1; fi; exit 0'

    run env \
        RETRY_MAX_ATTEMPTS=3 RETRY_BACKOFF_INITIAL_SECONDS=0 \
        RETRY_BACKOFF_JITTER_RATIO=0 \
        bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [ "$(count_docker_attempts)" -eq 2 ]
    [[ "${output}" == *"retriable via classify_docker_registry"* ]]
}

@test "retry: permanent docker build failure exits immediately" {

    seed_minimal_workflow_repo

    # 'Permission denied' is not in any default classifier's pattern
    # set, so all three reject it and the primitive returns the build
    # exit code without further attempts.
    install_docker_stub build 'echo "Permission denied" >&2; exit 13'

    run env \
        RETRY_MAX_ATTEMPTS=5 RETRY_BACKOFF_INITIAL_SECONDS=0 \
        RETRY_BACKOFF_JITTER_RATIO=0 \
        bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 13 ]
    [ "$(count_docker_attempts)" -eq 1 ]
    [[ "${output}" == *"permanent (exit 13)"* ]]
}
