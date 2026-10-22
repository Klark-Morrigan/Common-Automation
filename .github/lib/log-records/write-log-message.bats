#!/usr/bin/env bats
# Unit tests for write-log-message.sh.
# Run with: bats .github/lib/log-records/write-log-message.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/write-log-message.sh
source "${BATS_TEST_DIRNAME}/write-log-message.sh"

@test "writes a message record, its pairs in order, to stderr alone" {

    run --separate-stderr write_log_message "" "Reading " id "Klark-Morrigan/Starsector-Mod-KMU"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "${stderr}" = "$(printf '#log\tmessage\t\tReading \tid\tKlark-Morrigan/Starsector-Mod-KMU')" ]
}
