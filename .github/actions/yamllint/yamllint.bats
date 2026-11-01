#!/usr/bin/env bats
# Unit tests for yamllint.sh - the composite action's helper that
# lints plain YAML outside the actionlint / action-validator surface.
# The most important contract is the skip-silently branch (covered
# without docker so it stays green on any workstation); pass/fail
# outcomes and config-discovery are covered against the locally-built
# common-automation/yamllint image so the bar matches what consumers
# actually experience. Docker-dependent tests `skip` cleanly when the engine
# is unavailable so the suite remains usable without it.

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/docker-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/yamllint.sh"

setup() {

    # Run each case from an isolated workdir so the fixture trees
    # cannot leak across tests and so PWD-based file discovery in
    # the script sees only what the test created.
    workdir="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "${workdir}"
}

@test "skips silently when no plain YAML files exist" {

    # Pre-image-resolution branch - no docker required, so this test
    # locks the no-op contract even on bare workstations. An empty
    # workdir trivially has nothing to lint.
    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping"* ]]
}

@test "skips silently when all YAML lives under excluded paths" {

    # YAML present but only under .github/workflows/ - covered by
    # actionlint, must not be picked up by yamllint.
    mkdir -p "${workdir}/.github/workflows"

    printf 'name: x\non: [push]\njobs: {}\n' \
        > "${workdir}/.github/workflows/ci.yml"

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping"* ]]
}

@test "exits 0 on a clean plain-YAML fixture" {

    require_docker

    # A minimal file that passes the bundled `default` ruleset:
    # leading `---`, key/value, trailing newline, no trailing spaces.
    cat > "${workdir}/data.yml" <<'YAML'
---
greeting: hello
YAML

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
}

@test "exits non-zero on a fixture with a known violation" {

    require_docker

    # Duplicate keys are an unconditional error in yamllint's
    # `default` ruleset across versions - a stable choice for the
    # failure-path contract.
    cat > "${workdir}/bad.yml" <<'YAML'
---
key: one
key: two
YAML

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -ne 0 ]
}

seed_minimal_yaml_repo() {

    # Bypass the skip-silently branch so the retry / build / run pipeline
    # is exercised. Content is irrelevant - the docker run is stubbed.
    printf -- '---\nkey: value\n' > "${workdir}/data.yml"
}

# Fetching itself is ensure-docker-image.bats's to cover; this case shows the
# helper builds through it, the error named after the helper. A permanent
# failure is not retried, so the case needs no backoff settings.
@test "ends without linting when the image build fails for good" {

    seed_minimal_yaml_repo
    install_docker_stub build 'echo "Permission denied" >&2; exit 13'

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 13 ]
    [[ "${output}" == *"::error::yamllint: could not build common-automation/yamllint:"* ]]
    [ -z "$(read_docker_run_arguments)" ]
}

@test "mounts the working folder and the action folder read-only by their docker host paths, offline" {

    seed_minimal_yaml_repo

    install_docker_stub build 'exit 0'
    install_cygpath_stub

    # The script names its own folder as cd and pwd leave it: absolute, with
    # no relative segments. BATS_TEST_DIRNAME is however bats was invoked.
    local action_dir
    action_dir="$(cd "${BATS_TEST_DIRNAME}" && pwd)"

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "$(read_docker_run_arguments)" == *$'--network\nnone\n'* ]]
    [[ "$(read_docker_run_arguments)" == *"C:/host${workdir}:/work:ro"* ]]
    [[ "$(read_docker_run_arguments)" == *"C:/host${action_dir}:/action:ro"* ]]
}

@test "logs how many files it lints and the folder it mounts" {

    seed_minimal_yaml_repo

    install_docker_stub build 'exit 0'
    install_cygpath_stub

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Linting 1 file(s) in C:/host${workdir}"* ]]
}

@test "honours a consumer-supplied .yamllint config" {

    require_docker

    # A file that fails `default` (no document-start marker) plus a
    # consumer config that disables the rule. If the config is read,
    # the run passes; if the bundled default is used instead, it
    # fails. This proves the discovery path, not yamllint internals.
    cat > "${workdir}/data.yml" <<'YAML'
greeting: hello
YAML
    cat > "${workdir}/.yamllint" <<'YAML'
extends: default
rules:
  document-start: disable
YAML

    run bash -c "cd '${workdir}' && '${SCRIPT}'"

    [ "${status}" -eq 0 ]
}
