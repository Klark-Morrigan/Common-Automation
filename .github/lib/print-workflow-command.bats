#!/usr/bin/env bats
# Unit tests for print-workflow-command.sh.
# Run with: bats .github/lib/print-workflow-command.bats

# shellcheck source=SCRIPTDIR/print-workflow-command.sh
source "${BATS_TEST_DIRNAME}/print-workflow-command.sh"

@test "prints the command with its text" {

    run print_workflow_command "${WORKFLOW_COMMAND_ERROR}" "example-stage: failed."

    [ "${status}" -eq 0 ]
    [ "${output}" = "::error::example-stage: failed." ]
}

@test "prints a command that takes no text" {

    run print_workflow_command "${WORKFLOW_COMMAND_END_GROUP}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "::endgroup::" ]
}

# The percent goes first, so the escapes it writes are not escaped again.
@test "escapes a percent sign, a carriage return and a newline in the text" {

    run print_workflow_command "${WORKFLOW_COMMAND_NOTICE}" $'50% done\r\nnext'

    [ "${status}" -eq 0 ]
    [ "${output}" = "::notice::50%25 done%0D%0Anext" ]
}
