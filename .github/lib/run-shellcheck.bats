#!/usr/bin/env bats
# Unit tests for run-shellcheck.sh.
# Run with: bats .github/lib/run-shellcheck.bats
#
# shellcheck, docker and cygpath are all stubbed, and PATH holds the stubs and
# bash alone, so each case runs the same whether or not the host has them.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/run-shellcheck.sh
source "${BATS_TEST_DIRNAME}/run-shellcheck.sh"

# shellcheck source=SCRIPTDIR/test-helpers/docker-stub.bash
source "${BATS_TEST_DIRNAME}/test-helpers/docker-stub.bash"

setup() {

    stub_dir="${BATS_TEST_TMPDIR}/path-stubs"

    # The stubs start with `#!/usr/bin/env bash`, so bash must stay findable.
    install_real_command bash
    install_docker_stub pull 'exit 0'
    install_cygpath_stub
}

# Runs run_shellcheck with the stubs as the whole PATH. Set here rather than
# around bats' run, which needs the host's tools to capture stderr.
#   run_shellcheck_on_stub_path <shellcheck argument...>
run_shellcheck_on_stub_path() {

    PATH="${stub_dir}" run_shellcheck "$@"
}

@test "runs the native shellcheck with the given arguments when it is on PATH" {

    install_path_stub shellcheck <<'STUB'
#!/usr/bin/env bash
printf 'native %s\n' "$*"
exit 3
STUB

    run --separate-stderr run_shellcheck_on_stub_path --severity=style -- a.sh

    [ "${status}" -eq 3 ]
    [ "${output}" = "native --severity=style -- a.sh" ]
    [ ! -e "${DOCKER_RUN_ARGUMENTS_FILE}" ]
}

@test "runs the pinned image over the current folder when shellcheck is not on PATH" {

    run --separate-stderr run_shellcheck_on_stub_path --severity=style -- a.sh

    [ "${status}" -eq 0 ]
    [ "$(read_docker_run_arguments)" = "--rm
-v
C:/host${PWD}:/work
-w
/work
koalaman/shellcheck:v0.10.0
--severity=style
--
a.sh" ]
}

@test "says on stderr that it falls back to the image" {

    run --separate-stderr run_shellcheck_on_stub_path -- a.sh

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "shellcheck is not on PATH; running koalaman/shellcheck:v0.10.0 over C:/host${PWD}." ]
}
