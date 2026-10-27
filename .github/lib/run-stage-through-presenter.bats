#!/usr/bin/env bats
# Unit tests for run-stage-through-presenter.sh.
# Run with: bats .github/lib/run-stage-through-presenter.bats
#
# The presenter is a stub that marks each line it passes, so a case can see
# which lines went through it. The failure lines are written outside it, so
# they come back unmarked.

# run ! and run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# What the presenter stub puts before each line it passes.
PRESENTED_PREFIX="presented: "

setup() {

    PRESENTER="${BATS_TEST_TMPDIR}/present-log-for-example.sh"
    STAGE_SCRIPT="${BATS_TEST_TMPDIR}/example-stage.sh"

    cat > "${PRESENTER}" <<STUB
#!/usr/bin/env bash
while IFS= read -r line; do
    printf '${PRESENTED_PREFIX}%s\n' "\${line}"
done
STUB
    chmod +x "${PRESENTER}"

    # shellcheck source=SCRIPTDIR/run-stage-through-presenter.sh
    source "${BATS_TEST_DIRNAME}/run-stage-through-presenter.sh"

    unset LOG_RECORDS STAGE_SECRET
}

# Replaces the presenter with one that reads nothing and exits 4.
#   write_failing_presenter
write_failing_presenter() {

    printf '#!/usr/bin/env bash\nexit 4\n' > "${PRESENTER}"
}

# Replaces the presenter with one that writes its whole environment to
# ${PRESENTER_ENVIRONMENT_FILE}, then passes its input on.
#   write_environment_recording_presenter
write_environment_recording_presenter() {

    export PRESENTER_ENVIRONMENT_FILE="${BATS_TEST_TMPDIR}/presenter.environment"

    printf '#!/usr/bin/env bash\nenv > "%s"\ncat\n' "${PRESENTER_ENVIRONMENT_FILE}" > "${PRESENTER}"
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

@test "passes the stage's stderr through the presenter" {

    write_stage_script <<'BODY'
echo "counted 3 assets." >&2
BODY

    run --separate-stderr run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "${PRESENTED_PREFIX}counted 3 assets." ]
}

@test "leaves the stage's stdout out of the presenter" {

    write_stage_script <<'BODY'
printf '1.2.3\ten\t40\n'
BODY

    run --separate-stderr run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = $'1.2.3\ten\t40' ]
    [ -z "${stderr}" ]
}

@test "hands the stage its arguments" {

    write_stage_script <<'BODY'
printf '%s\n' "$@"
BODY

    run run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}" "KMU" "a b"

    [ "${output}" = "KMU
a b" ]
}

# workflow-commands.sh reads it to write its annotations as records.
@test "runs the stage with LOG_RECORDS set to true" {

    write_stage_script <<'BODY'
printf '%s\n' "${LOG_RECORDS:-<unset>}"
BODY

    run run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${output}" = "true" ]
}

# A token held by the chain reaches the stage that needs it and nothing else.
@test "exports a variable named with --export to the stage alone, never the presenter" {

    write_environment_recording_presenter
    write_stage_script <<'BODY'
printf '%s\n' "${STAGE_SECRET:-<unset>}"
BODY
    STAGE_SECRET="s3cret"

    run run_stage_through_presenter "${PRESENTER}" --export STAGE_SECRET "${STAGE_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "s3cret" ]
    run ! grep -qF "s3cret" "${PRESENTER_ENVIRONMENT_FILE}"
}

@test "leaves a variable named with --export unexported for its caller" {

    write_stage_script <<'BODY'
BODY
    STAGE_SECRET="s3cret"

    run_stage_through_presenter "${PRESENTER}" --export STAGE_SECRET "${STAGE_SCRIPT}"

    [[ "$(declare -p STAGE_SECRET)" != "declare -x"* ]]
}

@test "keeps an unexported variable it was not asked for from the stage" {

    write_stage_script <<'BODY'
printf '%s\n' "${STAGE_SECRET:-<unset>}"
BODY
    STAGE_SECRET="s3cret"

    run run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${output}" = "<unset>" ]
}

@test "fails, running nothing, when --export has no name" {

    write_stage_script <<'BODY'
echo "ran." >&2
BODY

    run --separate-stderr run_stage_through_presenter "${PRESENTER}" --export

    [ "${status}" -ne 0 ]
    [[ "${stderr}" != *"ran."* ]]
}

@test "leaves LOG_RECORDS unset for its caller" {

    write_stage_script <<'BODY'
BODY

    run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ -z "${LOG_RECORDS+set}" ]
}

# Without PIPESTATUS a caller lacking pipefail would read the presenter's 0.
@test "returns the stage's status, not the presenter's, without pipefail" {

    write_stage_script <<'BODY'
exit 3
BODY

    set +o pipefail
    run run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${status}" -eq 3 ]
}

# A stage that crashed may have logged nothing of its own.
@test "logs a failed stage's exit status after its log" {

    write_stage_script <<'BODY'
echo "reading." >&2
exit 3
BODY

    run --separate-stderr run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${status}" -eq 3 ]
    [ "${stderr}" = "${PRESENTED_PREFIX}reading.
example-stage failed with exit status 3." ]
}

@test "logs nothing of its own for a stage that succeeds" {

    write_stage_script <<'BODY'
echo "reading." >&2
BODY

    run --separate-stderr run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "${PRESENTED_PREFIX}reading." ]
}

# The stage's log is lost with the presenter, so the run must not pass clean.
@test "fails with the presenter's status, naming it and the stage, when only the presenter fails" {

    write_failing_presenter
    write_stage_script <<'BODY'
BODY

    run --separate-stderr run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${status}" -eq 4 ]
    [[ "${stderr}" == "::error::"*"present-log-for-example.sh exited 4 while example-stage ran"* ]]
}

@test "returns the stage's status when both the stage and the presenter fail" {

    write_failing_presenter
    write_stage_script <<'BODY'
exit 3
BODY

    run --separate-stderr run_stage_through_presenter "${PRESENTER}" "${STAGE_SCRIPT}"

    [ "${status}" -eq 3 ]
    [[ "${stderr}" == *"example-stage failed with exit status 3."* ]]
    [[ "${stderr}" == *"present-log-for-example.sh exited 4"* ]]
}
