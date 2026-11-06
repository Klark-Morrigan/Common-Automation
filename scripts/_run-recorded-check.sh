#!/usr/bin/env bash
# Runs one check of a local CI run, so every runner reports its checks the
# same way: each one runs even after another fails, as CI's parallel jobs
# do, says how long it took, and lands in the one list the runner's summary
# names. Sourced, not executed: defines run_recorded_check and the
# failed_checks list it fills.

failed_checks=()

# Prints a heading naming <label>, runs <command...>, then prints
# "<label> passed in <n>s." or "<label> FAILED in <n>s." and a blank line.
# A failure appends <label> to failed_checks instead of ending the run.
#   run_recorded_check <label> <command...>
run_recorded_check() {

    local label="$1"
    local outcome="passed"
    local started_at="${SECONDS}"

    shift

    print_section_heading "${label}"

    # The `if` is what keeps a failing check from ending a `set -e` runner.
    # It also turns `set -e` off inside a command that is a function, so such
    # a command must return its own status.
    if ! "$@"; then
        outcome="FAILED"
        failed_checks+=("${label}")
    fi

    printf '%s %s in %ds.\n\n' "${label}" "${outcome}" "$(( SECONDS - started_at ))"
}
