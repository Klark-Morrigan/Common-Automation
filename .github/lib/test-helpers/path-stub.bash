#!/usr/bin/env bash
# Shared PATH stub installer for the bats suites. Sourced - never run - so it
# carries no tests itself and is skipped by the recursive *.bats runner.
#
# A stub first on PATH stands in for a command the script under test calls,
# while the script still runs its own invocation unchanged.

# Puts a stub for <command> first on PATH, its body read from stdin. Every
# stub a case installs shares one directory, put on PATH once, so a later stub
# replaces an earlier one of the same name.
#   install_path_stub <command> <<'STUB'
#   ...
#   STUB
install_path_stub() {

    local command_name="${1:?install_path_stub: command required}"

    # shellcheck disable=SC2154 # bats sets BATS_TEST_TMPDIR for every test
    local stub_dir="${BATS_TEST_TMPDIR}/path-stubs"

    mkdir -p "${stub_dir}"
    cat > "${stub_dir}/${command_name}"
    chmod +x "${stub_dir}/${command_name}"

    case ":${PATH}:" in
        *":${stub_dir}:"*)
            # Already first on PATH from an earlier stub.
            ;;
        *)
            export PATH="${stub_dir}:${PATH}"
            ;;
    esac
}

# Puts the real <command> in the stub directory, for a case that runs with the
# stubs as its whole PATH so that a tool the host has can be made absent. A
# wrapper rather than a link: Git Bash's executables need the DLLs beside
# them, so they only run from their own folder.
#   install_real_command <command>
install_real_command() {

    local real_command

    real_command="$(command -v "$1")"

    install_path_stub "$1" <<STUB
#!${BASH}
exec "${real_command}" "\$@"
STUB
}
