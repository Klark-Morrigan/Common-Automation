#!/usr/bin/env bats
# Unit tests for actionlint.sh - the composite action's helper that
# lints a repo's workflows (composite actions are linted transitively
# via `uses:` references from those workflows). The most important
# contract is the skip-silently branch (covered without docker so it
# stays green on any workstation) plus the pass/fail outcomes on real
# fixtures (covered through the pinned rhysd/actionlint image, so the
# bar matches what consumers actually experience). Docker-dependent
# tests `skip` cleanly when the engine is unavailable so the suite
# remains usable without it.

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/docker-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/actionlint.sh"

setup() {

    # Run each case from an isolated workdir so the fixture trees
    # cannot leak across tests and so PWD-based file discovery in the
    # script sees only what the test created.
    workdir="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "${workdir}"
}

@test "skips silently when workflows directory does not exist" {

    # Pre-image-resolution branch - no docker required, so this test
    # locks the no-op contract even on bare workstations.
    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping"* ]]
}

@test "exits 0 on a clean workflow fixture" {

    require_docker
    mkdir -p "${workdir}/.github/workflows"

    cat > "${workdir}/.github/workflows/clean.yml" <<'YAML'
name: clean
on: [push]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
YAML

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
}

@test "exits non-zero on a workflow with a schema error" {

    require_docker
    mkdir -p "${workdir}/.github/workflows"

    # A step with neither `run` nor `uses` is a schema error
    # actionlint flags reliably across versions - a stable choice for
    # the failure-path contract.
    cat > "${workdir}/.github/workflows/broken.yml" <<'YAML'
name: broken
on: [push]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - name: bare
YAML

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -ne 0 ]
}

seed_minimal_workflow_repo() {

    # Bypass the skip-silently branch so the pull / retry / run pipeline
    # is exercised. Workflow content is irrelevant - docker run is stubbed.
    mkdir -p "${workdir}/.github/workflows"

    cat > "${workdir}/.github/workflows/ci.yml" <<'YAML'
name: ci
on: [push]
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: echo hello
YAML

}

# Fetching itself is ensure-docker-image.bats's to cover; this case shows the
# helper pulls through it, the error named after the helper. A permanent
# failure is not retried, so the case needs no backoff settings.
@test "ends without linting when the image pull fails for good" {

    seed_minimal_workflow_repo
    install_docker_stub pull 'echo "Permission denied" >&2; exit 13'

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 13 ]
    [[ "${output}" == *"::error::actionlint: could not pull rhysd/actionlint:"* ]]
    [ -z "$(read_docker_run_arguments)" ]
}

@test "mounts the working folder read-only by its docker host path, offline" {

    seed_minimal_workflow_repo

    install_docker_stub pull 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *$'--network\nnone\n'* ]]
    [[ "$(read_docker_run_arguments)" == *"C:/host${workdir}:/repo:ro"* ]]
}

@test "logs how many workflows it lints and the folder it mounts" {

    seed_minimal_workflow_repo

    install_docker_stub pull 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Linting 1 workflow(s) in C:/host${workdir}"* ]]
}
