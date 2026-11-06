#!/usr/bin/env bats
# Unit tests for run-ci-yaml-and-bash.sh, the local CI orchestrator.
# Run with: bats scripts/run-ci-yaml-and-bash.bats
#
# The orchestrator runs its halves from its own folder, so each case copies
# it into a stand-in Common-Automation whose two halves are stubs. Each stub
# records what it was handed and exits with the status the case gives it.

setup() {

    # A full local run exports these into the suites it starts.
    unset COMMON_AUTOMATION_TARGET_REPO COMMON_AUTOMATION_TARGET_REPO_NAMED COMMON_AUTOMATION_NO_PAUSE

    STAND_IN_ROOT="${BATS_TEST_TMPDIR}/Common-Automation"
    STAND_IN_SCRIPTS_DIR="${STAND_IN_ROOT}/scripts"

    mkdir -p "${STAND_IN_SCRIPTS_DIR}" "${STAND_IN_ROOT}/.github/lib"

    cp "${BATS_TEST_DIRNAME}/run-ci-yaml-and-bash.sh" \
        "${BATS_TEST_DIRNAME}/_run-common.sh" \
        "${BATS_TEST_DIRNAME}/_hold-window.sh" \
        "${BATS_TEST_DIRNAME}/_run-recorded-check.sh" \
        "${BATS_TEST_DIRNAME}/_report-check-summary.sh" \
        "${STAND_IN_SCRIPTS_DIR}/"
    cp "${BATS_TEST_DIRNAME}/../.github/lib/print-section-heading.sh" "${STAND_IN_ROOT}/.github/lib/"
}

# Writes a stub half that records its target repo and pause setting to
# <half>.handed, then exits with <exit status>.
#   install_half_stub <half script name> <exit status>
install_half_stub() {

    local half="$1"

    cat > "${STAND_IN_SCRIPTS_DIR}/${half}" <<STUB
#!/usr/bin/env bash
printf 'target=%s pause-off=%s\n' "\${COMMON_AUTOMATION_TARGET_REPO}" "\${COMMON_AUTOMATION_NO_PAUSE:-}" \
    > "${BATS_TEST_TMPDIR}/${half}.handed"
exit $2
STUB
}

# Prints what the stub half was handed, or nothing when it never ran.
#   read_half_handed <half script name>
read_half_handed() {

    cat "${BATS_TEST_TMPDIR}/$1.handed" 2>/dev/null || true
}

@test "runs both halves and passes when both pass" {

    install_half_stub _run-lint-yaml-and-bash.sh 0
    install_half_stub _run-tests-bash.sh 0

    run "${STAND_IN_SCRIPTS_DIR}/run-ci-yaml-and-bash.sh"

    [ "${status}" -eq 0 ]
    [ "$(grep '^===' <<< "${output}")" = "=== lint ===
=== bash tests ===" ]
    [[ "${output}" == *"All checks passed."* ]]
}

@test "still runs the bash tests after the lint half fails, then names it" {

    install_half_stub _run-lint-yaml-and-bash.sh 1
    install_half_stub _run-tests-bash.sh 0

    run "${STAND_IN_SCRIPTS_DIR}/run-ci-yaml-and-bash.sh"

    [ "${status}" -eq 1 ]
    [ -n "$(read_half_handed _run-tests-bash.sh)" ]
    [ "$(sed -n '/^FAILED/,$p' <<< "${output}")" = "FAILED (all checks):
  lint" ]
}

@test "names both halves when both fail" {

    install_half_stub _run-lint-yaml-and-bash.sh 1
    install_half_stub _run-tests-bash.sh 1

    run "${STAND_IN_SCRIPTS_DIR}/run-ci-yaml-and-bash.sh"

    [ "${status}" -eq 1 ]
    [ "$(sed -n '/^FAILED/,$p' <<< "${output}")" = "FAILED (all checks):
  lint
  bash tests" ]
}

@test "hands both halves Common-Automation as the target, with their pause off" {

    install_half_stub _run-lint-yaml-and-bash.sh 0
    install_half_stub _run-tests-bash.sh 0

    run "${STAND_IN_SCRIPTS_DIR}/run-ci-yaml-and-bash.sh"

    [ "$(read_half_handed _run-lint-yaml-and-bash.sh)" = "target=${STAND_IN_ROOT} pause-off=1" ]
    [ "$(read_half_handed _run-tests-bash.sh)" = "target=${STAND_IN_ROOT} pause-off=1" ]
}

@test "hands both halves the target repo it was given" {

    install_half_stub _run-lint-yaml-and-bash.sh 0
    install_half_stub _run-tests-bash.sh 0
    export COMMON_AUTOMATION_TARGET_REPO="${BATS_TEST_TMPDIR}/target"

    run "${STAND_IN_SCRIPTS_DIR}/run-ci-yaml-and-bash.sh"

    [ "$(read_half_handed _run-lint-yaml-and-bash.sh)" = "target=${COMMON_AUTOMATION_TARGET_REPO} pause-off=1" ]
    [ "$(read_half_handed _run-tests-bash.sh)" = "target=${COMMON_AUTOMATION_TARGET_REPO} pause-off=1" ]
}
