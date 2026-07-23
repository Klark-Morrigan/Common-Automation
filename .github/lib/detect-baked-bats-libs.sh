#!/usr/bin/env bash
# Prints, for each bats helper library bats-action can install, whether
# bats-action should still install it: "<lib>_install=true" when the
# library is absent from the runner, "<lib>_install=false" when it is
# already present. The test-bats composite action feeds these lines into
# bats-action's *-install inputs so a library already baked onto the
# runner is not reinstalled - that reinstall writes to /usr/lib with sudo,
# which fails on a runner whose CI user has no passwordless sudo.
#
# A library is "present" when its load.bash exists under <base>/bats-<lib>/
# (the layout bats-action installs into). Pure stdout printer, like the
# get-*-version.sh accessors: the action redirects the output to
# $GITHUB_OUTPUT rather than this script knowing about GitHub Actions, so
# it stays unit-testable in isolation.
#
# The library set is exactly bats-action's four installable libraries
# (support, assert, detik, file). This list is the source of truth for the
# detection; the action's `with:` block must enumerate the matching
# *-install inputs by hand, because a composite action cannot template
# that block over a dynamic set. Keep the two in sync - if bats-action ever
# gains a fifth library, it is added here AND as a `with:` line.
#
# Usage: detect-baked-bats-libs.sh [base-dir]
#   [base-dir]  Library base directory to probe; defaults to /usr/lib, the
#               Linux path bats-action installs into. test-bats targets
#               Linux runners (see the action description).

set -euo pipefail

base="${1:-/usr/lib}"

for lib in support assert detik file; do
    if [[ -f "${base}/bats-${lib}/load.bash" ]]; then
        printf '%s_install=false\n' "${lib}"
    else
        printf '%s_install=true\n' "${lib}"
    fi
done
