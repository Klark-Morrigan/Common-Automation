#!/usr/bin/env bash
# A git whose push fails, for the suites that publish a badge branch. Sourced -
# never run - so it carries no tests itself and is skipped by the recursive
# *.bats runner.

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/path-stub.bash
source "${BASH_SOURCE[0]%/*}/../../../lib/test-helpers/path-stub.bash"

# Puts a git on PATH whose every push fails as a dropped connection does. With
# "landed", the push reaches the remote first, so only its answer is lost.
#   install_failing_push_git [landed]
install_failing_push_git() {

    local real_git
    local landed="${1:-}"

    real_git="$(command -v git)"

    install_path_stub git <<STUB
#!/usr/bin/env bash
if [[ " \$* " == *" push "* ]]; then
    [[ "${landed}" == "landed" ]] && "${real_git}" "\$@"
    echo "fatal: the remote end hung up unexpectedly" >&2
    exit 128
fi
exec "${real_git}" "\$@"
STUB
}
