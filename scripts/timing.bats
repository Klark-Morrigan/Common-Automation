#!/usr/bin/env bats
# Unit tests for scripts/timing.sh - the shared nested-span timing emitter that
# writes the e2e-timing/v1 JSON tree consumed cross-process by Infrastructure-
# E2E (feature 88 E1). Run with: bats scripts/timing.bats
#
# Each test drives a tiny flow script that sources the real emitter and issues
# spans, then asserts on the artifact it leaves (or does not leave). Driving a
# separate script - rather than sourcing timing.sh into the bats process -
# keeps the EXIT-trap flush firing on a process this test owns and starts the
# emitter from clean module state per run.

setup() {
    TIMING_SH="${BATS_TEST_DIRNAME}/timing.sh"
    DRIVER="${BATS_TEST_TMPDIR}/flow.sh"
    OUT="${BATS_TEST_TMPDIR}/tree.json"
    # Never leak a real caller's opt-in into a test expecting the unset path.
    unset TIMING_TREE_OUTPUT_PATH
}

# Write a flow driver whose body is the span script passed on stdin. The driver
# runs under `set -euo pipefail` like the production flows, so a test exercises
# the emitter under the same shell strictness the real ops/ scripts use.
write_driver() {
    {
        printf '#!/usr/bin/env bash\n'
        printf 'set -euo pipefail\n'
        printf 'source %q\n' "${TIMING_SH}"
        cat
    } >"${DRIVER}"
}

# Assert the given text parses as JSON when a parser is available; otherwise
# fall back to a structural check so the suite still runs on the bare bats
# image (no jq / python3). The stronger nesting assertions are jq-gated per
# test where they add value.
assert_valid_json() {
    local text="$1"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "${text}" | jq empty
        return
    fi
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "${text}" | python3 -c 'import json,sys; json.load(sys.stdin)'
        return
    fi
    [[ "${text}" == '{"schema":'*'}' ]]
}

@test "env unset: writes no file and emits nothing" {
    write_driver <<'FLOW'
timing_init "flow-root"
timing_span_begin "stage"
timing_span_end
FLOW
    run bash "${DRIVER}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ ! -e "${OUT}" ]
}

@test "env set: writes a schema-tagged, valid JSON tree with the root name" {
    write_driver <<'FLOW'
timing_init "flow-root"
timing_span_begin "stage"
timing_span_end
FLOW
    TIMING_TREE_OUTPUT_PATH="${OUT}" run bash "${DRIVER}"
    [ "${status}" -eq 0 ]
    [ -f "${OUT}" ]
    json="$(cat "${OUT}")"
    assert_valid_json "${json}"
    [[ "${json}" == *'"schema":"e2e-timing/v1"'* ]]
    [[ "${json}" == *'"name":"flow-root"'* ]]
    [[ "${json}" == *'"name":"stage"'* ]]
}

@test "spans nest under their parent" {
    write_driver <<'FLOW'
timing_init "flow-root"
timing_span_begin "dispatch"
timing_span_begin "inner"
timing_span_end
timing_span_end
FLOW
    TIMING_TREE_OUTPUT_PATH="${OUT}" run bash "${DRIVER}"
    [ "${status}" -eq 0 ]
    json="$(cat "${OUT}")"
    assert_valid_json "${json}"
    # 'inner' is emitted inside 'dispatch' (its object follows dispatch's).
    [[ "${json}" == *'"name":"dispatch"'*'"name":"inner"'* ]]
    if command -v jq >/dev/null 2>&1; then
        run bash -c "jq -r '.root.children[] | select(.name==\"dispatch\") | .children[0].name' '${OUT}'"
        [ "${output}" = "inner" ]
    fi
}

@test "a --failed span marks the span and stickily the root Failed" {
    write_driver <<'FLOW'
timing_init "flow-root"
timing_span_begin "ok-span"
timing_span_end
timing_span_begin "bad-span"
timing_span_end --failed
FLOW
    TIMING_TREE_OUTPUT_PATH="${OUT}" run bash "${DRIVER}"
    [ "${status}" -eq 0 ]
    json="$(cat "${OUT}")"
    assert_valid_json "${json}"
    [[ "${json}" == *'"name":"bad-span","status":"Failed"'* ]]
    # A later success does not clear the root: it stays Failed.
    [[ "${json}" == *'"name":"flow-root","status":"Failed"'* ]]
}

@test "a mid-span abort still writes the tree with the open span Failed" {
    # set -e aborts inside the open span; the EXIT-trap flush must still emit a
    # well-formed tree up to the failure - the report-on-failure contract.
    write_driver <<'FLOW'
timing_init "flow-root"
timing_span_begin "dispatch"
false
timing_span_end
FLOW
    TIMING_TREE_OUTPUT_PATH="${OUT}" run bash "${DRIVER}"
    [ "${status}" -ne 0 ]
    [ -f "${OUT}" ]
    json="$(cat "${OUT}")"
    assert_valid_json "${json}"
    [[ "${json}" == *'"name":"dispatch","status":"Failed"'* ]]
    [[ "${json}" == *'"name":"flow-root","status":"Failed"'* ]]
}

@test "order reflects first-contact declaration order across depths" {
    write_driver <<'FLOW'
timing_init "flow-root"
timing_span_begin "first"
timing_span_end
timing_span_begin "second"
timing_span_begin "second-child"
timing_span_end
timing_span_end
FLOW
    TIMING_TREE_OUTPUT_PATH="${OUT}" run bash "${DRIVER}"
    [ "${status}" -eq 0 ]
    json="$(cat "${OUT}")"
    assert_valid_json "${json}"
    [[ "${json}" == *'"order":0,"name":"flow-root"'* ]]
    [[ "${json}" == *'"order":1,"name":"first"'* ]]
    [[ "${json}" == *'"order":2,"name":"second"'* ]]
    [[ "${json}" == *'"order":3,"name":"second-child"'* ]]
}
