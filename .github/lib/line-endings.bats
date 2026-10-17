#!/usr/bin/env bats
# Unit tests for line-endings.sh.
# Run with: bats .github/lib/line-endings.bats

# shellcheck source=SCRIPTDIR/line-endings.sh
source "${BATS_TEST_DIRNAME}/line-endings.sh"

@test "deletes every carriage return" {

    printf 'a\r\nb\r\n' | strip_carriage_returns > "${BATS_TEST_TMPDIR}/output"

    [ "$(od -An -c < "${BATS_TEST_TMPDIR}/output" | tr -s ' ')" = " a \n b \n" ]
}

@test "keeps a last line that has no newline" {

    run strip_carriage_returns < <(printf 'a\r\nb')

    [ "${status}" -eq 0 ]
    [ "${output}" = "a
b" ]
}

@test "prints nothing for empty input" {

    strip_carriage_returns < /dev/null > "${BATS_TEST_TMPDIR}/output"

    [ ! -s "${BATS_TEST_TMPDIR}/output" ]
}
