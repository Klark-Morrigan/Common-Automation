#!/usr/bin/env bats
# Unit tests for workflow-commands.sh.
# Run with: bats .github/lib/workflow-commands.bats
#
# The annotations name the running script, so each case runs a small script
# that sources the helper, rather than calling it from the suite.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

LIB="${BATS_TEST_DIRNAME}/workflow-commands.sh"

setup() {

    # run_stage sets it for a stage; a case that wants records sets it itself.
    unset LOG_RECORDS
}

# Writes an executable script, named after a stage, that sources the helper
# and then runs its body, read from stdin. Prints its path.
#   write_stage_script <<BODY
write_stage_script() {

    local stage_script="${BATS_TEST_TMPDIR}/example-stage.sh"

    {
        printf '#!/usr/bin/env bash\nset -euo pipefail\nsource "%s"\n' "${LIB}"
        cat
    } > "${stage_script}"

    chmod +x "${stage_script}"
    printf '%s' "${stage_script}"
}

@test "exit_with_error prints an error annotation naming the script, to stderr alone" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
exit_with_error "the input is" "missing."
BODY
)"

    run --separate-stderr "${stage_script}"

    [ -z "${output}" ]
    [ "${stderr}" = "::error::example-stage: the input is missing." ]
}

@test "exit_with_error exits 1 before the next line runs" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
exit_with_error "stop."
echo "ran on"
BODY
)"

    run --separate-stderr "${stage_script}"

    [ "${status}" -eq 1 ]
    [[ "${stderr}" != *"ran on"* ]]
    [ -z "${output}" ]
}

@test "log_error prints an error annotation naming the script, to stderr alone, and carries on" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
log_error "the lookup" "failed."
echo "ran on"
BODY
)"

    run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "ran on" ]
    [ "${stderr}" = "::error::example-stage: the lookup failed." ]
}

@test "require_value fails with an error annotation naming the input when its value is empty" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
require_value "LABEL" ""
echo "ran on"
BODY
)"

    run --separate-stderr "${stage_script}"

    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
    [ "${stderr}" = "::error::example-stage: LABEL is required." ]
}

@test "require_value carries on when the value is set" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
require_value "LABEL" "tool"
echo "ran on"
BODY
)"

    run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "ran on" ]
    [ -z "${stderr}" ]
}

@test "log_notice prints a notice annotation naming the script, to stderr alone, and carries on" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
log_notice "nothing to publish."
echo "ran on"
BODY
)"

    run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "ran on" ]
    [ "${stderr}" = "::notice::example-stage: nothing to publish." ]
}

@test "with LOG_RECORDS, exit_with_error writes an error record naming the script, and exits 1" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
exit_with_error "the input is" "missing."
echo "ran on"
BODY
)"

    LOG_RECORDS=true run --separate-stderr "${stage_script}"

    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\terror\t\texample-stage: the input is missing.')" ]
}

@test "with LOG_RECORDS, log_notice writes a notice record naming the script" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
log_notice "nothing to publish."
BODY
)"

    LOG_RECORDS=true run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "$(printf '#log\tnotice\t\texample-stage: nothing to publish.')" ]
}

# Only "true" opts in, as run_stage sets it.
@test "with LOG_RECORDS set to anything but true, writes the annotation itself" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
log_error "the lookup failed."
BODY
)"

    LOG_RECORDS=false run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "::error::example-stage: the lookup failed." ]
}
