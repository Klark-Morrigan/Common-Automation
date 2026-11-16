#!/usr/bin/env bash
# Ends a local CI run with one verdict over its checks, so a runner's last
# lines say what failed without scrolling back.
# Sourced, not executed: defines report_check_summary.

# Lists the failed checks, one per line on stderr under "FAILED (<scope>):",
# and returns 1; with none failed, prints "<Scope> passed." and returns 0.
#   report_check_summary <scope> [failed check...]
report_check_summary() {

    local scope="$1"

    shift

    if (( $# > 0 )); then

        echo "FAILED (${scope}):" >&2
        printf '  %s\n' "$@" >&2

        return 1
    fi

    echo "${scope^} passed."
}
