#!/usr/bin/env bash
# shellcheck disable=SC2034  # common_automation_root / repo_root are consumed by the sourcing entry scripts, not here
# Shared setup for the runners under scripts/ that act on a target repo.
# Kept as one sourced file so none of them can drift on how they resolve
# the target repo or arm the hold-window pause.
#
# Sets, for the sourcing script:
#   script_dir             - this scripts/ directory
#   common_automation_root - Common-Automation repo root (helper anchor)
#   repo_root              - the repo under check: the target repo named
#                            by COMMON_AUTOMATION_TARGET_REPO, else
#                            Common-Automation itself
# and defines print_section_heading, which every one of them heads its
# sections with.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
common_automation_root="$(cd "${script_dir}/.." && pwd)"
repo_root="${COMMON_AUTOMATION_TARGET_REPO:-${common_automation_root}}"

# A repo's shims run these runners against that repo, so the first line
# says which one is under check. A runner started by another runner
# inherits the marker and stays quiet, so a full run names it once.
if [[ "${COMMON_AUTOMATION_TARGET_REPO_NAMED:-}" != "1" ]]; then
    echo "Target repo: ${repo_root}"
    export COMMON_AUTOMATION_TARGET_REPO_NAMED=1
fi

# shellcheck source=SCRIPTDIR/_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT

# shellcheck source=SCRIPTDIR/../.github/lib/print-section-heading.sh
source "${common_automation_root}/.github/lib/print-section-heading.sh"
