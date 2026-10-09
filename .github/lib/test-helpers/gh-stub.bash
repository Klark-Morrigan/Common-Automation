#!/usr/bin/env bash
# Shared gh stub for the bats suites of scripts that shell out to gh. Sourced -
# never run - so it carries no tests itself and is skipped by the recursive
# *.bats runner.
#
# The stub keeps every suite off the network and off real credentials.

# shellcheck source=./path-stub.bash
source "${BASH_SOURCE[0]%/*}/path-stub.bash"

# Puts a gh stub first on PATH. Each call to the stub writes its arguments to
# ${GH_ARGS_FILE}, one per line so a multi-line value lands verbatim, and the
# number of calls so far to ${GH_CALLS_FILE}. It then replays the case's
# answer:
#   GH_STUB_STDOUT  printed to stdout   Default: nothing
#   GH_STUB_STDERR  printed to stderr   Default: nothing
#   GH_STUB_EXIT    exit status         Default: 0
# Any of the three suffixed with a call number - GH_STUB_EXIT_1 - answers that
# call alone, so a case can fail the first attempt and let a retry succeed.
#
# Every GH_STUB_* variable is cleared here, so an answer left in the
# environment bats was started from cannot reach a case. Both files exist only
# once gh was called, so a suite asserts "gh was never called" by their
# absence.
install_gh_stub() {

    install_path_stub gh <<'STUB'
#!/usr/bin/env bash
call=$(( $(cat "${GH_CALLS_FILE}" 2> /dev/null || echo 0) + 1 ))
printf '%s\n' "${call}" > "${GH_CALLS_FILE}"
printf '%s\n' "$@" > "${GH_ARGS_FILE}"
stdout_var="GH_STUB_STDOUT_${call}"
stderr_var="GH_STUB_STDERR_${call}"
exit_var="GH_STUB_EXIT_${call}"
stdout="${!stdout_var-${GH_STUB_STDOUT:-}}"
stderr="${!stderr_var-${GH_STUB_STDERR:-}}"
[[ -n "${stdout}" ]] && printf '%s\n' "${stdout}"
[[ -n "${stderr}" ]] && printf '%s\n' "${stderr}" >&2
exit "${!exit_var-${GH_STUB_EXIT:-0}}"
STUB

    # shellcheck disable=SC2154 # bats sets BATS_TEST_TMPDIR for every test
    export GH_ARGS_FILE="${BATS_TEST_TMPDIR}/gh.args"
    export GH_CALLS_FILE="${BATS_TEST_TMPDIR}/gh.calls"

    local stub_variables=("${!GH_STUB_@}")

    if (( ${#stub_variables[@]} > 0 )); then
        unset "${stub_variables[@]}"
    fi
}
