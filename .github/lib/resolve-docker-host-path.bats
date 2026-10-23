#!/usr/bin/env bats
# Unit tests for resolve-docker-host-path.sh.
# Run with: bats .github/lib/resolve-docker-host-path.bats
#
# cygpath is stubbed on PATH, or hidden from it, so each case runs the same
# whichever shell the suite runs under.

# shellcheck source=SCRIPTDIR/resolve-docker-host-path.sh
source "${BATS_TEST_DIRNAME}/resolve-docker-host-path.sh"

# shellcheck source=SCRIPTDIR/test-helpers/path-stub.bash
source "${BATS_TEST_DIRNAME}/test-helpers/path-stub.bash"

@test "prints cygpath's mixed form when cygpath is on PATH" {

    install_path_stub cygpath <<'STUB'
#!/usr/bin/env bash
[ "$1" = "-m" ] && printf 'C:/Users/me/AppData/Local/Temp%s\n' "${2#/tmp}"
STUB

    run resolve_docker_host_path "/tmp/repo"

    [ "${status}" -eq 0 ]
    [ "${output}" = "C:/Users/me/AppData/Local/Temp/repo" ]
}

@test "prints the path unchanged when cygpath is not on PATH" {

    # Bash builtins only, so an empty PATH hides cygpath without breaking the
    # function.
    PATH="" run resolve_docker_host_path "/tmp/repo"

    [ "${status}" -eq 0 ]
    [ "${output}" = "/tmp/repo" ]
}
