#!/usr/bin/env bash
# Strict shellcheck on extension-less git hook files under a directory
# (default `.githooks/`). The canonical SHELLCHECK_FLAGS array is
# sourced from the sibling shellcheck-bash helper so the strict bar
# stays single-sourced.
#
# Modes:
#
#   - Executed:  ./shellcheck-hooks.sh [hooks-dir]
#     Lints every hook file at the top level of <hooks-dir>: in a git
#     work tree, the tracked ones alone (see lib/list-hook-files.sh).
#     A missing directory, or one holding no hook file, is a no-op
#     (notice + exit 0). Lints through lib/run-shellcheck.sh, which runs
#     the pinned Docker image.
#
#   - Sourced is not supported: the sibling helper is the canonical
#     sourced-mode entry for SHELLCHECK_FLAGS.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pull SHELLCHECK_FLAGS via the sibling action's helper. Sourced mode
# returns before its own runner block, so this leaves the array
# defined in the current shell without executing shellcheck.
# shellcheck source=SCRIPTDIR/../shellcheck-bash/shellcheck-bash.sh
source "${script_dir}/../shellcheck-bash/shellcheck-bash.sh"

# shellcheck source=SCRIPTDIR/../../lib/list-hook-files.sh
source "${script_dir}/../../lib/list-hook-files.sh"

# shellcheck source=SCRIPTDIR/../../lib/run-shellcheck.sh
source "${script_dir}/../../lib/run-shellcheck.sh"

hooks_dir="${1:-.githooks}"

if [[ ! -d "${hooks_dir}" ]]; then
    echo "::notice::${hooks_dir} does not exist, skipping"
    exit 0
fi

hook_list="$(list_hook_files "${hooks_dir}")"

if [[ -z "${hook_list}" ]]; then
    echo "::notice::no files under ${hooks_dir}/, skipping"
    exit 0
fi

mapfile -t hook_files <<< "${hook_list}"

# shellcheck disable=SC2154  # SHELLCHECK_FLAGS set by source above
run_shellcheck "${SHELLCHECK_FLAGS[@]}" -- "${hook_files[@]}"
