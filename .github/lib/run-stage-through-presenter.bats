#!/usr/bin/env bats
# Unit tests for run-stage-through-presenter.sh.
# Run with: bats .github/lib/run-stage-through-presenter.bats
#
# The presenter is a stub that marks each line it passes, so a case can see
# which lines went through it.

# run --separate-stderr arrived in 1.5.0.
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

    unset LOG_RECORDS
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
