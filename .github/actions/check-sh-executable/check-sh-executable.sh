#!/usr/bin/env bash
#
# Fails when a tracked .sh file lacks the executable bit in the git index.
#
# Files written on Windows land in git as mode 0644.
# On a Linux runner that breaks `bats run` (EACCES, exit 126)
# and any other direct run of the script.
#
# The bats job fails too,
# but every test then fails with an opaque status mismatch;
# this gate names each file and the one-line fix.
#
# Every tracked .sh, by design, never a subtree.
# The detector is the fixes' own, so the gate and the fixes agree.

set -euo pipefail

# shellcheck source=SCRIPTDIR/../../lib/fixes/list-paths-missing-executable-bit.sh
source "${BASH_SOURCE[0]%/*}/../../lib/fixes/list-paths-missing-executable-bit.sh"

missing="$(list_paths_missing_executable_bit '*.sh')"

if [[ -n "${missing}" ]]; then
    echo "::error::these .sh files are missing +x in the git index:"
    echo "${missing}"
    echo "Fix with: git update-index --chmod=+x <path>"
    exit 1
fi
