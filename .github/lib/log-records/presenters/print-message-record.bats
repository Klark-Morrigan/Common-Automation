#!/usr/bin/env bats
# Unit tests for print-message-record.sh.
# Run with: bats .github/lib/log-records/presenters/print-message-record.bats

# shellcheck source=SCRIPTDIR/print-message-record.sh
source "${BATS_TEST_DIRNAME}/print-message-record.sh"

setup() {

    unset NO_COLOR FORCE_COLOR
}

@test "prints the values in order as one line, each as its role shows it" {

    run print_message_record "$(printf '#log\tmessage\t\tDefault locale \tlocale\tzh-hans\t\t.')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Default locale ZH-HANS." ]
}

@test "prints nothing for a last role that has no text" {

    run print_message_record "$(printf '#log\tmessage\t\tRead \tid')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Read " ]
}

@test "prints an empty line for a message with no pairs" {

    run print_message_record "$(printf '#log\tmessage')"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
