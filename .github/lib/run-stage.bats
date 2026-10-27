#!/usr/bin/env bats
# Unit tests for run-stage.sh.
# Run with: bats .github/lib/run-stage.bats
#
# The function finds its collaborators beside its own file, so each case
# sources a copy of it from a stand-in lib tree. There
# run_stage_through_presenter is a stub that names the presenter it was
# handed, then runs the stage, so a case can see which path the stage took.
# print_section_heading and print_workflow_command are the real ones: their
# lines are the framing under test. So are resolve_log_presenter, whose choice
# the stub names, and is_running_in_github_actions, which reads GITHUB_ACTIONS.
#
# GITHUB_ACTIONS is set or unset by every case, since bats itself may run
# under GitHub Actions or outside it.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# What the run_stage_through_presenter stub logs before it runs the stage.
PRESENTED_BY_PREFIX="presented by "

setup() {

    local stand_in_lib="${BATS_TEST_TMPDIR}/lib"

    STAGE_SCRIPT="${BATS_TEST_TMPDIR}/example-stage.sh"

    mkdir -p "${stand_in_lib}/log-records/presenters"
    cp "${BATS_TEST_DIRNAME}/run-stage.sh" \
        "${BATS_TEST_DIRNAME}/is-running-in-github-actions.sh" \
        "${BATS_TEST_DIRNAME}/print-section-heading.sh" \
        "${BATS_TEST_DIRNAME}/print-workflow-command.sh" \
        "${stand_in_lib}/"
    cp "${BATS_TEST_DIRNAME}/log-records/presenters/resolve-log-presenter.sh" \
        "${stand_in_lib}/log-records/presenters/"

    cat > "${stand_in_lib}/run-stage-through-presenter.sh" <<STUB
run_stage_through_presenter() {
    echo "${PRESENTED_BY_PREFIX}\${1##*/}" >&2
    shift
    "\$@"
}
STUB

    # shellcheck source=SCRIPTDIR/run-stage.sh
    source "${stand_in_lib}/run-stage.sh"

    write_stage_script <<'BODY'
echo "stage ran with: $*" >&2
printf 'data\n'
exit "${STAGE_EXIT:-0}"
BODY

    unset STAGE_EXIT
}

# Writes the stage script, its body read from stdin.
#   write_stage_script <<'BODY'
write_stage_script() {

    {
        printf '#!/usr/bin/env bash\n'
        cat
    } > "${STAGE_SCRIPT}"

    chmod +x "${STAGE_SCRIPT}"
}

@test "under GitHub Actions, wraps the stage's log in a group named after its file and shapes it for Actions" {

    export GITHUB_ACTIONS=true
    run --separate-stderr run_stage "${STAGE_SCRIPT}" "KMU"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "::group::example-stage
${PRESENTED_BY_PREFIX}present-log-for-github-actions.sh
stage ran with: KMU
::endgroup::" ]
}

@test "under GitHub Actions, leaves the stage's stdout alone" {

    export GITHUB_ACTIONS=true
    run --separate-stderr run_stage "${STAGE_SCRIPT}"

    [ "${output}" = "data" ]
}

@test "under GitHub Actions, closes the group of a failed stage and returns its status" {

    export GITHUB_ACTIONS=true
    export STAGE_EXIT=3
    run --separate-stderr run_stage "${STAGE_SCRIPT}"

    [ "${status}" -eq 3 ]
    [ "${stderr_lines[-1]}" = "::endgroup::" ]
}

@test "outside GitHub Actions, heads the stage's log with its name and shapes it for the terminal" {

    unset GITHUB_ACTIONS
    run --separate-stderr run_stage "${STAGE_SCRIPT}" "KMU"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "=== example-stage ===
${PRESENTED_BY_PREFIX}present-log-for-terminal.sh
stage ran with: KMU" ]
    [ "${output}" = "data" ]
}

@test "outside GitHub Actions, returns a failed stage's status" {

    unset GITHUB_ACTIONS
    export STAGE_EXIT=3
    run --separate-stderr run_stage "${STAGE_SCRIPT}"

    [ "${status}" -eq 3 ]
}
