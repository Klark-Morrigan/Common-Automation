#!/usr/bin/env bats
# Unit tests for yamllint.sh - the composite action's helper that
# lints plain YAML outside the actionlint / action-validator surface.
# The most important contract is the skip-silently branch (covered
# without docker so it stays green on any workstation); pass/fail
# outcomes and config-discovery are covered against the pinned
# cytopia/yamllint image so the bar matches what consumers actually
# experience. Docker-dependent tests `skip` cleanly when the engine
# is unavailable so the suite remains usable without it.

SCRIPT="${BATS_TEST_DIRNAME}/yamllint.sh"

setup() {
    # Run each case from an isolated workdir so the fixture trees
    # cannot leak across tests and so PWD-based file discovery in
    # the script sees only what the test created.
    workdir="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "${workdir}"
}

require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        skip "docker not on PATH"
    fi
    if ! docker info >/dev/null 2>&1; then
        skip "docker daemon not running"
    fi
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
