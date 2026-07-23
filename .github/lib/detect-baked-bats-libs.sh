#!/usr/bin/env bash
# Prints, for each bats helper library bats-action can install, whether
# bats-action should install it: "<lib>_install=true" to install,
# "<lib>_install=false" to skip. The test-bats composite action feeds these
# lines into bats-action's *-install inputs. Pure stdout printer, like the
# get-*-version.sh accessors: the action redirects the output to
# $GITHUB_OUTPUT rather than this script knowing about GitHub Actions, so it
# stays unit-testable in isolation.
#
# bats-action installs the libraries into <base>/bats-<lib>/ with sudo. Two
# reasons to skip an install, either of which yields install=false:
#
#   1. The library is already baked onto the runner (its load.bash exists
#      under <base>/bats-<lib>/) - reinstalling would be redundant.
#   2. The runner cannot sudo without a password. The install writes to the
#      base dir via sudo, so without passwordless sudo it CANNOT run at all -
#      an install=true would just fail with "a password is required",
#      whether or not the suite uses that library. On such a runner the only
#      libraries available are the baked ones; every install is skipped and
#      a suite that needs an unbaked library must have it baked (a load-time
#      "library not found" is a far clearer signal than a sudo password
#      error). On a runner WITH passwordless sudo (e.g. GitHub-hosted), a
#      missing library installs as normal.
#
# The library set is exactly bats-action's four installable libraries
# (support, assert, detik, file). This list is the source of truth for the
# detection; the action's `with:` block must enumerate the matching
# *-install inputs by hand, because a composite action cannot template that
# block over a dynamic set. Keep the two in sync - if bats-action ever gains
# a fifth library, it is added here AND as a `with:` line.
#
# Usage: detect-baked-bats-libs.sh [base-dir]
#   [base-dir]  Library base directory to probe; defaults to /usr/lib, the
#               Linux path bats-action installs into. test-bats targets
#               Linux runners (see the action description).
#
# Env:
#   BATS_LIBS_CAN_SUDO  Override the passwordless-sudo probe with 1 or 0.
#                       Unset probes `sudo -n true`. Exists so the unit tests
#                       are deterministic instead of depending on the test
#                       host's sudo configuration.

set -euo pipefail

base="${1:-/usr/lib}"

# Can an install (sudo write to the base dir) run without a password prompt?
if [[ -n "${BATS_LIBS_CAN_SUDO:-}" ]]; then
    can_sudo="${BATS_LIBS_CAN_SUDO}"
elif sudo -n true 2>/dev/null; then
    can_sudo=1
else
    can_sudo=0
fi

for lib in support assert detik file; do
    if [[ -f "${base}/bats-${lib}/load.bash" || "${can_sudo}" != "1" ]]; then
        printf '%s_install=false\n' "${lib}"
    else
        printf '%s_install=true\n' "${lib}"
    fi
done
