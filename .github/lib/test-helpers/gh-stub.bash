#!/usr/bin/env bash
# Shared gh stub for the bats suites of scripts that shell out to gh
# (create-github-release, summarise-release-downloads). Sourced - never run -
# so it carries no tests itself and is skipped by the recursive *.bats runner.
#
# A stub on PATH keeps every suite off the network and off real credentials,
# while the script under test still runs its own gh invocation unchanged.

# Puts a gh stub first on PATH. The stub writes the arguments of its latest
# call to ${GH_ARGS_FILE}, one per line so a multi-line value lands verbatim,
# then replays the case's answer:
#   GH_STUB_STDOUT  printed to stdout   Default: nothing
#   GH_STUB_STDERR  printed to stderr   Default: nothing
#   GH_STUB_EXIT    exit status         Default: 0
# The three are cleared here, so one test's answer cannot leak into the next.
# ${GH_ARGS_FILE} exists only once gh was called, so a suite asserts "gh was
# never called" by its absence.
install_gh_stub() {

    # shellcheck disable=SC2154 # bats sets BATS_TEST_TMPDIR for every test
    local stub_dir="${BATS_TEST_TMPDIR}/gh-stub"

    mkdir -p "${stub_dir}"

    cat > "${stub_dir}/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${GH_ARGS_FILE}"
[[ -n "${GH_STUB_STDOUT:-}" ]] && printf '%s\n' "${GH_STUB_STDOUT}"
[[ -n "${GH_STUB_STDERR:-}" ]] && printf '%s\n' "${GH_STUB_STDERR}" >&2
exit "${GH_STUB_EXIT:-0}"
STUB

    chmod +x "${stub_dir}/gh"

    export GH_ARGS_FILE="${BATS_TEST_TMPDIR}/gh.args"
    export PATH="${stub_dir}:${PATH}"

    unset GH_STUB_STDOUT GH_STUB_STDERR GH_STUB_EXIT
}
