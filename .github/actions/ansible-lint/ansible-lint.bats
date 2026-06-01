#!/usr/bin/env bats
# Unit tests for ansible-lint.sh - the composite action's helper that
# lints Ansible content. The most important contract is the auto-skip
# branch when no Ansible content exists (covered without docker so it
# stays green on any workstation); pass/fail outcomes and config-
# discovery are covered against the locally-built
# github-common/ansible-lint image so the bar matches what consumers
# actually experience. Docker-dependent tests `skip` cleanly when the
# engine is unavailable so the suite remains usable without it.

SCRIPT="${BATS_TEST_DIRNAME}/ansible-lint.sh"

setup() {
    # Run each case from an isolated workdir so the fixture trees
    # cannot leak across tests and so PWD-based detection in the
    # script sees only what the test created.
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

@test "auto-skips when no Ansible content exists" {
    # Pre-image-resolution branch - no docker required, so this test
    # locks the no-op contract even on bare workstations. An empty
    # workdir trivially has none of ansible.cfg/playbooks/roles.
    run bash -c "cd '${workdir}' && '${SCRIPT}'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping"* ]]
}

@test "auto-skips when only unrelated YAML is present" {
    # A repo with arbitrary YAML but no Ansible markers must still
    # auto-skip - the detection key is structural (ansible.cfg /
    # playbooks/ / roles/), not "any YAML".
    printf 'greeting: hello\n' > "${workdir}/data.yml"
    run bash -c "cd '${workdir}' && '${SCRIPT}'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping"* ]]
}

@test "exits 0 on a minimal valid playbook" {
    require_docker
    # Minimal playbook that satisfies the `production` profile:
    # explicit name, fqcn module, no-changed-when handled because
    # debug doesn't change state.
    mkdir -p "${workdir}/playbooks"
    cat > "${workdir}/playbooks/site.yml" <<'YAML'
---
- name: Smoke test play
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Print a message
      ansible.builtin.debug:
        msg: hello
YAML
    run bash -c "cd '${workdir}' && '${SCRIPT}'"
    [ "${status}" -eq 0 ]
}

@test "exits non-zero on a playbook with a known violation" {
    require_docker
    # `command` instead of a module + missing changed_when is a stable
    # double-violation across ansible-lint versions on the production
    # profile.
    mkdir -p "${workdir}/playbooks"
    cat > "${workdir}/playbooks/bad.yml" <<'YAML'
---
- name: Bad play
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Run a raw command
      ansible.builtin.command: /bin/true
YAML
    run bash -c "cd '${workdir}' && '${SCRIPT}'"
    [ "${status}" -ne 0 ]
}

@test "honours a consumer-supplied .ansible-lint config" {
    require_docker
    # Same bad playbook as above, but a consumer config downgrades the
    # production profile to `min` which does not enforce
    # command-instead-of-module or no-changed-when. If the consumer
    # config is read the run passes; if the bundled production default
    # is used instead it fails. This proves the discovery path, not
    # ansible-lint internals.
    mkdir -p "${workdir}/playbooks"
    cat > "${workdir}/playbooks/bad.yml" <<'YAML'
---
- name: Bad play
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Run a raw command
      ansible.builtin.command: /bin/true
YAML
    cat > "${workdir}/.ansible-lint" <<'YAML'
profile: min
YAML
    run bash -c "cd '${workdir}' && '${SCRIPT}'"
    [ "${status}" -eq 0 ]
}
