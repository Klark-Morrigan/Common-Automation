#!/usr/bin/env bash
# Sourced retry primitive. Wraps an arbitrary command in a bounded
# retry loop so callers don't reinvent the same `until ... sleep ...`
# pattern. See docs/dev/implementation/22-bash-retry-primitive/ for
# the locked decisions this file implements.
#
# Step 1 scope: budget enforcement only - fixed 1 s sleep, always
# retry on non-zero. Backoff (step 2) and classifiers (steps 3-4)
# replace the relevant branches in later commits.
#
# Usage (in a composite action's *.sh, where SCRIPT_DIR is
# `.github/actions/<name>/`):
#
#   # shellcheck source=../../lib/retry.sh
#   source "${SCRIPT_DIR}/../../lib/retry.sh"
#   retry_command "docker build" -- docker build -t foo .
#
# Env vars (read by retry_command, optional):
#
#   RETRY_MAX_ATTEMPTS  Max attempts including the first try. Default 5.
#   RETRY_MAX_SECONDS   Wall-clock budget across all attempts.   Default 300.

# Runs <cmd...> repeatedly until it succeeds, the attempt count is
# exhausted, or the wall-clock deadline is hit - whichever fires first.
# Returns 0 on success, the command's last non-zero exit on exhaustion,
# or 2 on usage error. Output is passthrough: stdin/stdout/stderr of
# the wrapped command reach the caller unchanged; only this function's
# own diagnostics carry the `retry:` prefix and go to stderr.
retry_command() {
    # Argument shape: <op-name> -- <command...>. op-name is required
    # so diagnostics name the failing operation; `--` separates it
    # from the command vector so the command can contain arbitrary
    # flags without ambiguity.
    if [[ $# -lt 1 || -z "${1:-}" || "${1}" == "--" ]]; then
        echo "retry: usage: retry_command <op-name> -- <command...>" >&2
        return 2
    fi
    local op_name="$1"
    shift

    if [[ $# -lt 1 || "${1}" != "--" ]]; then
        echo "retry: usage: retry_command <op-name> -- <command...>" >&2
        return 2
    fi
    shift

    if [[ $# -lt 1 ]]; then
        echo "retry: usage: retry_command <op-name> -- <command...>" >&2
        return 2
    fi

    local max_attempts="${RETRY_MAX_ATTEMPTS:-5}"
    local max_seconds="${RETRY_MAX_SECONDS:-300}"

    # Absolute deadline rather than a per-attempt timer so a sequence
    # of quick failures and short sleeps still adds up against one
    # shared budget - matches the "whichever ceiling fires first"
    # contract in problem.md.
    local deadline=$(( $(date +%s) + max_seconds ))
    local attempt=0
    local exit_code=0

    while :; do
        attempt=$(( attempt + 1 ))

        # Inherit stdin/stdout/stderr - no capture in step 2; the
        # classifier step (4) introduces tee'd capture for inspection
        # without breaking this passthrough contract.
        "$@"
        exit_code=$?

        if (( exit_code == 0 )); then
            return 0
        fi

        if (( attempt >= max_attempts )); then
            echo "retry: ${op_name} exhausted attempts (${max_attempts})" >&2
            return "${exit_code}"
        fi

        # Deadline check uses `>=` so RETRY_MAX_SECONDS=0 means "no
        # retry" (deadline equals start; the first failed attempt
        # is already past it).
        local now
        now=$(date +%s)
        if (( now >= deadline )); then
            echo "retry: ${op_name} exhausted seconds (${max_seconds})" >&2
            return "${exit_code}"
        fi

        echo "retry: ${op_name} attempt ${attempt} failed (exit ${exit_code}), retrying in 1s" >&2
        sleep 1
    done
}
