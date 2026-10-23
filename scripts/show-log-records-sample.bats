#!/usr/bin/env bats
# Unit tests for show-log-records-sample.sh.
# Run with: bats scripts/show-log-records-sample.bats
#
# The presenter's own suite holds the layout. These cases only prove the
# sample reaches the presenter whole.

SCRIPT="${BATS_TEST_DIRNAME}/show-log-records-sample.sh"

setup() {

    unset NO_COLOR FORCE_COLOR
}

@test "prints the sample shaped, with no record left raw" {

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Reading the releases of Klark-Morrigan/Starsector-Mod-KMU, default locale EN."* ]]
    [[ "${output}" == *"retry: list the releases attempt 1 failed"* ]]
    [[ "${output}" == *"KMU-0.2.0-zh-hans.zip  ZH-HANS          7"* ]]
    [[ "${output}" != *"#log"* ]]
}

@test "colours the sample when colour is forced" {

    FORCE_COLOR=1 run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *$'\033[90mARCHIVED\033[0m'* ]]
}
