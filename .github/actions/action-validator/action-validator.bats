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

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/docker-stub.bash
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

# Fetching itself is ensure-docker-image.bats's to cover; this case shows the
# helper builds through it, the error named after the helper. A permanent
# failure is not retried, so the case needs no backoff settings.
@test "ends without validating when the image build fails for good" {

    seed_minimal_workflow_repo
    install_docker_stub build 'echo "Permission denied" >&2; exit 13'

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 13 ]
    [[ "${output}" == *"::error::action-validator: could not build common-automation/action-validator:"* ]]
    [ -z "$(read_docker_run_arguments)" ]
}

@test "mounts the working folder read-only by its docker host path, offline" {

    seed_minimal_workflow_repo

    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *$'--network\nnone\n'* ]]
    [[ "$(read_docker_run_arguments)" == *"C:/host${workdir}:/repo:ro"* ]]
}

@test "logs how many files it validates and the folder it mounts" {

    seed_minimal_workflow_repo

    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Validating 1 file(s) in C:/host${workdir}"* ]]
}
