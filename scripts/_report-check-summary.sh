#!/usr/bin/env bash
# Ends a local CI run with one verdict over every check run_recorded_check
# ran, so a runner's last lines say what failed without scrolling back.
# Sourced, not executed: defines report_check_summary.

# Lists the failed_checks that run_recorded_check filled, one per line on
# stderr under "FAILED (<scope>):", and returns 1; with none failed, prints
# "<Scope> passed." and returns 0.
#   report_check_summary <scope>
report_check_summary() {

    local scope="$1"

    if (( ${#failed_checks[@]} > 0 )); then

        echo "FAILED (${scope}):" >&2
        printf '  %s\n' "${failed_checks[@]}" >&2

        return 1
    fi

    echo "${scope^} passed."
}
