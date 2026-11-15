#!/usr/bin/env bats
#
# Unit tests for run-lint-yaml-and-bash.sh, the entry name of the lint half.
# Run with: bats scripts/run-lint-yaml-and-bash.bats
#
# The shim runs the half from its own folder, so each case copies it into a
# stand-in scripts/ whose half is a stub that records its arguments and
# exits with the status the case gives it.

setup() {

    STAND_IN_SCRIPTS_DIR="${BATS_TEST_TMPDIR}/scripts"
    half_arguments_file="${BATS_TEST_TMPDIR}/half-arguments"

    mkdir -p "${STAND_IN_SCRIPTS_DIR}"
    cp "${BATS_TEST_DIRNAME}/run-lint-yaml-and-bash.sh" "${STAND_IN_SCRIPTS_DIR}/"
}

# Writes the stub half, which records its arguments and exits with the given status.
#   install_half_stub <exit status>
install_half_stub() {

    cat > "${STAND_IN_SCRIPTS_DIR}/_run-lint-yaml-and-bash.sh" <<STUB
#!/usr/bin/env bash
printf 'ran with %s argument(s)\n' "\$#" > "${half_arguments_file}"
exit $1
STUB
    chmod +x "${STAND_IN_SCRIPTS_DIR}/_run-lint-yaml-and-bash.sh"
}

@test "runs the lint half with no arguments and passes when it passes" {

    install_half_stub 0
    run "${STAND_IN_SCRIPTS_DIR}/run-lint-yaml-and-bash.sh"

    [ "${status}" -eq 0 ]
    [ "$(cat "${half_arguments_file}")" = "ran with 0 argument(s)" ]
}

@test "fails with the lint half's exit status" {

    install_half_stub 3
    run "${STAND_IN_SCRIPTS_DIR}/run-lint-yaml-and-bash.sh"

    [ "${status}" -eq 3 ]
}
