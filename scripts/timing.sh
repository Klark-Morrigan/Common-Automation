#!/usr/bin/env bash
# Shared timing-span emitter: records named, optionally-nested spans across a
# shell flow and writes them as the versioned nested-JSON tree
# (schema "e2e-timing/v1") the Infrastructure-E2E orchestrator imports and
# grafts under the flow's part span (feature 88, sections C2 / E1). It is the
# bash counterpart of Common.PowerShell's Export-TimingSpanTree and emits the
# SAME on-disk shape, so a bash flow's sub-steps merge into the E2E timing
# report exactly like a PowerShell child's do. Consumed cross-repo (the ops/
# ansible flows) via a thin imports/_timing.sh resolver shim, the same way
# scripts/log.sh is.
#
# OPT-IN, no-op by default. Every verb short-circuits unless
# TIMING_TREE_OUTPUT_PATH is set - the neutral cross-process contract shared
# with the PowerShell emitters (the flow never names who consumes it). With the
# variable unset a flow writes no file, emits nothing, and installs no trap, so
# instrumenting a flow never changes its behaviour on the default,
# uninstrumented path.
#
# Model. A span stack mirrors the framework's current-node stack: timing_span_
# begin pushes a node, timing_span_end pops it and folds it into its parent's
# children, so spans nest to arbitrary depth. Each node carries the export
# schema's fields { order, name, status, elapsedMs, source, children }: order
# is first-contact declaration order (root = 0), status is OK or Failed (sticky
# at the root when any span failed). The tree is written ONCE, from an EXIT
# trap, so the artifact is produced on the success, failure, AND set -e abort
# paths - a flow that dies mid-span still emits a tree with its still-open spans
# marked Failed, the bash analogue of the PowerShell finally.
#
# Portability. Plain globals plus parallel indexed-array stacks (bash 3.2+), no
# associative arrays, so the emitter runs on the busybox/BSD shells the bats
# image and macOS CI use. Re-sourcing is harmless: only function definitions
# load here; all state is (re)initialised by timing_init.

# Reset every piece of module state. Called by timing_init so a second flow (or
# a re-init) starts from a known-clean tree rather than inheriting a prior run's
# stack. Arrays are declared here so `set -u` never trips on a first reference.
_timing_reset_state() {
    _TIMING_ENABLED=0
    _TIMING_OUTPUT_PATH=''
    _TIMING_ROOT_SOURCE=''
    _TIMING_NEXT_ORDER=1
    _TIMING_FAILED=0
    _TIMING_FLUSHED=0
    _TIMING_STACK_NAME=()
    _TIMING_STACK_ORDER=()
    _TIMING_STACK_START_MS=()
    _TIMING_STACK_CHILDREN=()
}

# timing_init <root-span-name>
#   Arm the emitter for one flow. The root name is the flow identity - the
#   report's total line and the node the E2E graft hangs this flow's sub-steps
#   under. A no-op (leaving every verb inert and installing no trap) unless the
#   opt-in variable is set, so a flow that calls this unconditionally still
#   behaves exactly as before when timing was not requested.
timing_init() {
    local root_name="$1"
    _timing_reset_state
    if [[ -z "${TIMING_TREE_OUTPUT_PATH:-}" ]]; then
        return 0
    fi
    _TIMING_ENABLED=1
    _TIMING_OUTPUT_PATH="${TIMING_TREE_OUTPUT_PATH}"
    # Bottom of the source stack = the executed entry script, so the root's
    # provenance tag names the flow the operator ran even though this helper is
    # sourced. Mirrors scripts/log.sh's entry-script attribution.
    _TIMING_ROOT_SOURCE="${BASH_SOURCE[$(( ${#BASH_SOURCE[@]} - 1 ))]##*/}"
    # Seed the stack with the root (order 0) so the first span attaches under it
    # without the caller managing the stack - mirrors New-TimingSpanTree.
    local now_ms
    now_ms="$(_timing_now_ms)"
    _TIMING_STACK_NAME+=("${root_name}")
    _TIMING_STACK_ORDER+=(0)
    _TIMING_STACK_START_MS+=("${now_ms}")
    _TIMING_STACK_CHILDREN+=('')
    # Emit on every exit path (success, failure, set -e abort) so the artifact
    # ships even when the flow dies mid-span.
    trap '_timing_flush' EXIT
}

# Predicate: true when timing was requested (TIMING_TREE_OUTPUT_PATH was set at
# init). Lets a caller keep its exact prior behaviour on the unset path - e.g.
# `exec`-ing a child instead of running it under a span - and only take the
# instrumented branch when someone is collecting a tree.
timing_enabled() {
    [[ "${_TIMING_ENABLED:-0}" -eq 1 ]]
}

# timing_span_begin <name>
#   Open a span named <name> under the current node. Nests: a begin issued while
#   another span is open attaches beneath it. No-op when timing is not enabled.
timing_span_begin() {
    [[ "${_TIMING_ENABLED:-0}" -eq 1 ]] || return 0
    local name="$1"
    local now_ms
    now_ms="$(_timing_now_ms)"
    _TIMING_STACK_NAME+=("${name}")
    _TIMING_STACK_ORDER+=("${_TIMING_NEXT_ORDER}")
    _TIMING_STACK_START_MS+=("${now_ms}")
    _TIMING_STACK_CHILDREN+=('')
    _TIMING_NEXT_ORDER=$(( _TIMING_NEXT_ORDER + 1 ))
}

# timing_span_end [--failed]
#   Close the innermost open span, record its elapsed and terminal status, and
#   fold it into its parent's children. --failed marks the span Failed and makes
#   the root stickily Failed. No-op when timing is not enabled.
timing_span_end() {
    [[ "${_TIMING_ENABLED:-0}" -eq 1 ]] || return 0
    local status='OK'
    if [[ "${1:-}" == '--failed' ]]; then
        status='Failed'
        _TIMING_FAILED=1
    fi
    _timing_close_top "${status}"
}

# Current wall clock in integer milliseconds.
_timing_now_ms() {
    # GNU date yields nanoseconds (%N); divide to ms. busybox/BSD date treat %N
    # as a literal 'N', so fall back to whole-second precision. The real ansible
    # flows run under WSL (GNU coreutils) and get true millisecond timing; the
    # fallback only keeps the emitter functional where %N is unsupported (the
    # bats image / macOS), where precise durations are not asserted.
    local ns
    ns="$(date +%s%N)"
    case "${ns}" in
        *[!0-9]*)
            # %N unsupported: 'ns' carries a literal N. Fall back to seconds.
            local s
            s="$(date +%s)"
            echo "$(( s * 1000 ))"
            ;;
        *) echo "$(( ns / 1000000 ))" ;;
    esac
}

# Pop the innermost open span, build its node JSON, and append it to its
# parent's accumulated children. The single implementation of the close +
# fold-into-parent mechanic, shared by timing_span_end and the flush-time
# force-close of spans left open by an abort. status is the terminal status to
# record for the span being closed.
_timing_close_top() {
    local status="$1"
    local top=$(( ${#_TIMING_STACK_NAME[@]} - 1 ))
    # Index 0 is the root; it is closed by _timing_flush, never popped here.
    [[ "${top}" -ge 1 ]] || return 0
    local name="${_TIMING_STACK_NAME[top]}"
    local order="${_TIMING_STACK_ORDER[top]}"
    local start="${_TIMING_STACK_START_MS[top]}"
    local children="${_TIMING_STACK_CHILDREN[top]}"
    local now elapsed node
    now="$(_timing_now_ms)"
    elapsed=$(( now - start ))
    # Child nodes carry no source tag (source belongs to the root); pass null.
    node="$(_timing_node_json "${order}" "${name}" "${status}" "${elapsed}" 'null' "${children}")"
    unset '_TIMING_STACK_NAME[top]' '_TIMING_STACK_ORDER[top]' \
        '_TIMING_STACK_START_MS[top]' '_TIMING_STACK_CHILDREN[top]'
    local parent=$(( ${#_TIMING_STACK_NAME[@]} - 1 ))
    _timing_append_child "${parent}" "${node}"
}

# Append a finished child node's JSON to the children accumulator at stack index
# <idx>, comma-joining so the slot holds a ready-to-bracket JSON array body.
_timing_append_child() {
    local idx="$1" node="$2"
    if [[ -n "${_TIMING_STACK_CHILDREN[idx]}" ]]; then
        _TIMING_STACK_CHILDREN[idx]="${_TIMING_STACK_CHILDREN[idx]},${node}"
    else
        _TIMING_STACK_CHILDREN[idx]="${node}"
    fi
}

# Serialise one node to the export schema's object shape. children is the raw
# comma-joined child bodies (empty for a leaf); source_json is a ready JSON
# value (the literal `null` or a quoted string), so callers decide provenance
# without this helper re-deciding it. camelCase keys match
# ConvertTo-TimingSpanExportNode so the PowerShell importer reads either side.
_timing_node_json() {
    local order="$1" name="$2" status="$3" elapsed="$4" source_json="$5" children="$6"
    # Escape into locals first so the printf below does not mask _timing_json_
    # string's return value (shellcheck SC2312).
    local name_json status_json
    name_json="$(_timing_json_string "${name}")"
    status_json="$(_timing_json_string "${status}")"
    printf '{"order":%s,"name":%s,"status":%s,"elapsedMs":%s,"source":%s,"children":[%s]}' \
        "${order}" "${name_json}" "${status_json}" "${elapsed}" \
        "${source_json}" "${children}"
}

# Escape a value as a JSON string literal (quotes included). Span names in these
# flows are plain ASCII, but escaping backslash and double-quote keeps the
# artifact valid should a caller ever pass a name containing either.
_timing_json_string() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '"%s"' "${s}"
}

# Write the accumulated tree to the opt-in path. Installed as the EXIT trap by
# timing_init, so it runs once on whatever path the flow leaves by.
_timing_flush() {
    [[ "${_TIMING_ENABLED:-0}" -eq 1 ]] || return 0
    # Idempotent: an explicit call plus the EXIT trap must not double-write.
    [[ "${_TIMING_FLUSHED:-0}" -eq 0 ]] || return 0
    _TIMING_FLUSHED=1
    # Force-close any spans still open (a mid-span abort) as Failed, deepest
    # first, folding each under its parent so the tree is well-formed up to the
    # point the flow died - the report then shows where it got to.
    while [[ "${#_TIMING_STACK_NAME[@]}" -gt 1 ]]; do
        _TIMING_FAILED=1
        _timing_close_top 'Failed'
    done
    local now elapsed root_status root_source_json root_json document
    now="$(_timing_now_ms)"
    elapsed=$(( now - _TIMING_STACK_START_MS[0] ))
    if [[ "${_TIMING_FAILED:-0}" -eq 1 ]]; then
        root_status='Failed'
    else
        root_status='OK'
    fi
    # Escape the root source into a local first so the node builder call does
    # not mask _timing_json_string's return value (shellcheck SC2312).
    root_source_json="$(_timing_json_string "${_TIMING_ROOT_SOURCE}")"
    root_json="$(_timing_node_json 0 "${_TIMING_STACK_NAME[0]}" "${root_status}" \
        "${elapsed}" "${root_source_json}" "${_TIMING_STACK_CHILDREN[0]}")"
    printf -v document '{"schema":"e2e-timing/v1","root":%s}\n' "${root_json}"
    # Write defensively: a failing write inside the EXIT trap must not mask the
    # flow's own exit status. The caller owns the parent directory (a
    # per-invocation temp path from the E2E orchestrator), so it should exist;
    # warn rather than error if it does not.
    if ! printf '%s' "${document}" >"${_TIMING_OUTPUT_PATH}" 2>/dev/null; then
        printf 'timing.sh: could not write timing tree to %s\n' \
            "${_TIMING_OUTPUT_PATH}" >&2
    fi
}
