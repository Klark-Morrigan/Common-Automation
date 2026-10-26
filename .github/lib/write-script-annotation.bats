#!/usr/bin/env bats
# Unit tests for write-script-annotation.sh.
# Run with: bats .github/lib/write-script-annotation.bats
#
# The annotation names the running script, so each case runs a small script
# that sources the helper, rather than calling it from the suite. The record
# writer is a stub that prints the values it was handed.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

LIB="${BATS_TEST_DIRNAME}/write-script-annotation.sh"

setup() {

    # run_stage sets it for a stage; a case that wants records sets it itself.
    unset LOG_RECORDS
}

# Writes an executable script, named after a stage, that sources the helper,
# defines the stub record writer and then runs its body, read from stdin.
# Prints its path.
#   write_stage_script <<BODY
write_stage_script() {

    local stage_script="${BATS_TEST_TMPDIR}/example-stage.sh"

    {
        printf '#!/usr/bin/env bash\nset -euo pipefail\nsource "%s"\n' "${LIB}"
        printf 'write_stub_record() { printf "record:[%%s]\\n" "$@" >&2; }\n'
        cat
    } > "${stage_script}"

    chmod +x "${stage_script}"
    printf '%s' "${stage_script}"
}

@test "writes the workflow command naming the script, to stderr alone" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
write_script_annotation warning write_stub_record "the lookup" "failed."
BODY
)"

    run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "::warning::example-stage: the lookup failed." ]
}

@test "with LOG_RECORDS true, hands the record writer a plain role and the text instead" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
write_script_annotation warning write_stub_record "the lookup failed."
BODY
)"

    LOG_RECORDS=true run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "record:[]
record:[example-stage: the lookup failed.]" ]
}

# Only "true" opts in, as run_stage sets it.
@test "with LOG_RECORDS set to anything but true, writes the workflow command" {

    local stage_script
    stage_script="$(write_stage_script <<'BODY'
write_script_annotation warning write_stub_record "the lookup failed."
BODY
)"

    LOG_RECORDS=false run --separate-stderr "${stage_script}"

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "::warning::example-stage: the lookup failed." ]
}
