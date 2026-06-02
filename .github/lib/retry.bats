#!/usr/bin/env bats
# Unit tests for scripts/lib/retry.sh (step 2: budget enforcement
# only). Backoff (step 3) and classifier (step 4) cases land
# alongside the code that introduces them.
#
# The primitive is sourced rather than executed - retry_command is a
# shell function, not a standalone script - so each test sources
# retry.sh into the test shell and calls retry_command directly.

setup() {
    # Each test gets its own scratch dir so attempt-counter files
    # don't leak between tests.
    TEST_TMP="$(mktemp -d)"
    # Reset budget env so a test setting one doesn't bleed into the
    # next. Tests that need a value set it explicitly.
    unset RETRY_MAX_ATTEMPTS RETRY_MAX_SECONDS
    # shellcheck source=./retry.sh
    source "${BATS_TEST_DIRNAME}/retry.sh"
}

teardown() {
    rm -rf "${TEST_TMP}"
}

# Builds a one-shot stub command at $TEST_TMP/cmd that increments a
# counter on each invocation and exits according to a caller-supplied
# script body. Returns the path to the stub. The body receives the
# current attempt number in $ATTEMPT.
make_stub() {
    local body="$1"
    local stub="${TEST_TMP}/cmd"
    cat > "${stub}" <<EOF
#!/usr/bin/env bash
counter="${TEST_TMP}/count"
ATTEMPT=\$(( \$(cat "\${counter}" 2>/dev/null || echo 0) + 1 ))
echo "\${ATTEMPT}" > "\${counter}"
${body}
EOF
    chmod +x "${stub}"
    echo "${stub}"
}

attempt_count() {
    cat "${TEST_TMP}/count" 2>/dev/null || echo 0
}

@test "succeeds on first attempt with no retry diagnostic" {
    stub="$(make_stub 'exit 0')"
    run retry_command "noop" -- "${stub}"
    [ "${status}" -eq 0 ]
    [ "$(attempt_count)" -eq 1 ]
    [[ "${output}" != *"retry:"* ]]
}

@test "retries until success and names the op on each failure" {
    # Fail twice, then succeed. Default max_attempts (5) is plenty.
    stub="$(make_stub 'if (( ATTEMPT < 3 )); then exit 7; fi; exit 0')"
    RETRY_MAX_SECONDS=30 run retry_command "flaky" -- "${stub}"
    [ "${status}" -eq 0 ]
    [ "$(attempt_count)" -eq 3 ]
    # Two retry diagnostics (one per failed attempt before success).
    count=$(printf '%s\n' "${output}" | grep -c "retry: flaky attempt")
    [ "${count}" -eq 2 ]
}

@test "exhausted attempts returns the command's last exit code" {
    stub="$(make_stub 'exit 13')"
    RETRY_MAX_ATTEMPTS=3 RETRY_MAX_SECONDS=30 run retry_command "always-fails" -- "${stub}"
    [ "${status}" -eq 13 ]
    [ "$(attempt_count)" -eq 3 ]
    [[ "${output}" == *"retry: always-fails exhausted attempts (3)"* ]]
}

@test "RETRY_MAX_ATTEMPTS=1 disables retry entirely" {
    stub="$(make_stub 'exit 5')"
    RETRY_MAX_ATTEMPTS=1 RETRY_MAX_SECONDS=30 run retry_command "once" -- "${stub}"
    [ "${status}" -eq 5 ]
    [ "$(attempt_count)" -eq 1 ]
    [[ "${output}" == *"exhausted attempts (1)"* ]]
}

@test "RETRY_MAX_SECONDS=0 ends after the first failed attempt" {
    stub="$(make_stub 'exit 9')"
    RETRY_MAX_ATTEMPTS=10 RETRY_MAX_SECONDS=0 run retry_command "no-time" -- "${stub}"
    [ "${status}" -eq 9 ]
    [ "$(attempt_count)" -eq 1 ]
    [[ "${output}" == *"exhausted seconds (0)"* ]]
}

@test "stdout from the wrapped command reaches the caller verbatim" {
    stub="$(make_stub 'echo "hello-from-cmd"; exit 0')"
    run retry_command "echoer" -- "${stub}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"hello-from-cmd"* ]]
}

@test "primitive diagnostics go to stderr with the retry: prefix" {
    stub="$(make_stub 'echo "real-output"; exit 4')"
    # Capture stdout and stderr separately to assert the routing.
    out_file="${TEST_TMP}/out"
    err_file="${TEST_TMP}/err"
    RETRY_MAX_ATTEMPTS=2 RETRY_MAX_SECONDS=30 retry_command "router" -- "${stub}" \
        >"${out_file}" 2>"${err_file}" || true
    grep -q "real-output" "${out_file}"
    ! grep -q "retry:" "${out_file}"
    grep -q "retry: router" "${err_file}"
}

@test "missing op-name argument is a usage error (exit 2)" {
    run retry_command
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"usage:"* ]]
}

@test "empty op-name argument is a usage error (exit 2)" {
    run retry_command "" -- true
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"usage:"* ]]
}

@test "first arg of -- is a usage error (op-name missing)" {
    run retry_command -- echo hi
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"usage:"* ]]
}

@test "missing -- separator is a usage error (exit 2)" {
    run retry_command "op" echo hi
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"usage:"* ]]
}

@test "missing command after -- is a usage error (exit 2)" {
    run retry_command "op" --
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"usage:"* ]]
}
