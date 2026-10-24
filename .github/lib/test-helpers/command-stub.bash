#!/usr/bin/env bash
# Shared command stub for the bats suites of scripts that shell out to a
# client of something outside the test - gh, curl, git against a remote.
# Sourced - never run - so it carries no tests itself and is skipped by the
# recursive *.bats runner.
#
# The stub keeps every suite off the network and off real credentials.

# shellcheck source=SCRIPTDIR/path-stub.bash
source "${BASH_SOURCE[0]%/*}/path-stub.bash"

# Puts a stub for <command> first on PATH. Its variables are prefixed with the
# command's name upper-cased, every other character but a digit made `_`: gh
# answers to GH_STUB_*, curl to CURL_STUB_*.
#
# Each call to the stub writes its arguments to ${<PREFIX>_ARGS_FILE}, one per
# line so a multi-line value lands verbatim, and the number of calls so far to
# ${<PREFIX>_CALLS_FILE}. It then replays the case's answer:
#   <PREFIX>_STUB_STDOUT  printed to stdout   Default: nothing
#   <PREFIX>_STUB_STDERR  printed to stderr   Default: nothing
#   <PREFIX>_STUB_EXIT    exit status         Default: 0
# Any of the three suffixed with a call number - GH_STUB_EXIT_1 - answers that
# call alone, so a case can fail the first attempt and let a retry succeed.
#
# Every <PREFIX>_STUB_* variable is cleared here, so an answer left in the
# environment bats was started from cannot reach a case. Both files exist only
# once the command was called, so a suite asserts "it was never called" by
# their absence.
#   install_command_stub <command>
install_command_stub() {

    local command_name="${1:?install_command_stub: command required}"
    local variable_prefix

    variable_prefix="$(derive_command_stub_prefix "${command_name}")"

    # shellcheck disable=SC2154 # bats sets BATS_TEST_TMPDIR for every test
    local args_file="${BATS_TEST_TMPDIR}/${command_name}.args"
    local calls_file="${BATS_TEST_TMPDIR}/${command_name}.calls"

    install_path_stub "${command_name}" <<STUB
#!/usr/bin/env bash
call=\$(( \$(cat "${calls_file}" 2> /dev/null || echo 0) + 1 ))
printf '%s\n' "\${call}" > "${calls_file}"
printf '%s\n' "\$@" > "${args_file}"
stdout_var="${variable_prefix}_STUB_STDOUT_\${call}"
stderr_var="${variable_prefix}_STUB_STDERR_\${call}"
exit_var="${variable_prefix}_STUB_EXIT_\${call}"
stdout="\${!stdout_var-\${${variable_prefix}_STUB_STDOUT:-}}"
stderr="\${!stderr_var-\${${variable_prefix}_STUB_STDERR:-}}"
[[ -n "\${stdout}" ]] && printf '%s\n' "\${stdout}"
[[ -n "\${stderr}" ]] && printf '%s\n' "\${stderr}" >&2
exit "\${!exit_var-\${${variable_prefix}_STUB_EXIT:-0}}"
STUB

    export "${variable_prefix}_ARGS_FILE=${args_file}"
    export "${variable_prefix}_CALLS_FILE=${calls_file}"

    local stub_variables

    # compgen fails when no variable matches, which here means nothing to clear.
    mapfile -t stub_variables < <(compgen -v "${variable_prefix}_STUB_" || true)

    if (( ${#stub_variables[@]} > 0 )); then
        unset "${stub_variables[@]}"
    fi
}

# Prints how many times the stub for <command> was called.
#   count_command_calls <command>
count_command_calls() {

    local calls_file_variable

    calls_file_variable="$(derive_command_stub_prefix "${1:?count_command_calls: command required}")_CALLS_FILE"

    cat "${!calls_file_variable}" 2> /dev/null || echo 0
}

# Prints the prefix of the stub variables for <command>.
#   derive_command_stub_prefix <command>
derive_command_stub_prefix() {

    local upper_cased="${1^^}"

    printf '%s\n' "${upper_cased//[^A-Z0-9]/_}"
}
