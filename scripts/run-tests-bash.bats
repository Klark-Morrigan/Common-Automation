#!/usr/bin/env bats
#
# Unit tests for run-tests-bash.sh, the entry name of the bats half.
# Run with: bats scripts/run-tests-bash.bats
#
# The shim runs the half from its own folder, so each case copies it into a
# stand-in scripts/ whose half is a stub that records its arguments and
# exits with the status the case gives it.

setup() {

    STAND_IN_SCRIPTS_DIR="${BATS_TEST_TMPDIR}/scripts"
    half_arguments_file="${BATS_TEST_TMPDIR}/half-arguments"

    mkdir -p "${STAND_IN_SCRIPTS_DIR}"
    cp "${BATS_TEST_DIRNAME}/run-tests-bash.sh" "${STAND_IN_SCRIPTS_DIR}/"
}

# Writes the stub half, which records its arguments and exits with the given status.
#   install_half_stub <exit status>
install_half_stub() {

    cat > "${STAND_IN_SCRIPTS_DIR}/_run-tests-bash.sh" <<STUB
#!/usr/bin/env bash
printf 'ran with %s argument(s)\n' "\$#" > "${half_arguments_file}"
exit $1
STUB
    chmod +x "${STAND_IN_SCRIPTS_DIR}/_run-tests-bash.sh"
}

@test "runs the bats half with no arguments and passes when it passes" {

    install_half_stub 0
    run "${STAND_IN_SCRIPTS_DIR}/run-tests-bash.sh"

    [ "${status}" -eq 0 ]
    [ "$(cat "${half_arguments_file}")" = "ran with 0 argument(s)" ]
}

@test "fails with the bats half's exit status" {

    install_half_stub 3
    run "${STAND_IN_SCRIPTS_DIR}/run-tests-bash.sh"

    [ "${status}" -eq 3 ]
}
