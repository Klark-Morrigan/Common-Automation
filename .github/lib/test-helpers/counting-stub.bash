#!/usr/bin/env bash
# Shared attempt-counting command for the bats suites of the retry primitive
# and the actions built on it. Sourced - never run - so it carries no tests
# itself and is skipped by the recursive *.bats runner.

# Writes a command that counts its own calls and then runs <body>, with the
# attempt number in ATTEMPT, so a case decides each attempt's outcome. Prints
# the command's path.
#   create_counting_stub <body>
create_counting_stub() {

    # shellcheck disable=SC2154 # bats sets BATS_TEST_TMPDIR for every test
    local stub="${BATS_TEST_TMPDIR}/counting-stub"
    local calls_file

    calls_file="$(resolve_counting_stub_calls_file)"

    cat > "${stub}" <<STUB
#!/usr/bin/env bash
ATTEMPT=\$(( \$(cat "${calls_file}" 2> /dev/null || echo 0) + 1 ))
echo "\${ATTEMPT}" > "${calls_file}"
${1:?create_counting_stub: body required}
STUB

    chmod +x "${stub}"
    printf '%s\n' "${stub}"
}

# Prints how many times the stub was called.
count_stub_attempts() {

    local calls_file

    calls_file="$(resolve_counting_stub_calls_file)"

    cat "${calls_file}" 2> /dev/null || echo 0
}

# Prints the file the stub counts its calls in. Resolved on each call rather
# than exported, because callers create the stub inside $(...), where an
# export would not reach them.
resolve_counting_stub_calls_file() {

    printf '%s\n' "${BATS_TEST_TMPDIR}/counting-stub.calls"
}
