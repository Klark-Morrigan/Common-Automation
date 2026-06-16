#!/usr/bin/env bash
# shellcheck disable=SC2034  # common_automation_root / repo_root are consumed by the sourcing entry scripts, not here
# Shared setup for the local check entry points - the lint half
# (_run-lint-yaml-and-bash.sh), the bash-test half (_run-tests-bash.sh),
# and the run-ci-yaml-and-bash.sh orchestrator that runs both. Kept as
# one sourced file so the three entries cannot drift on how they resolve
# the target repo or arm the hold-window pause.
#
# Sets, for the sourcing script:
#   script_dir             - this scripts/ directory
#   common_automation_root - Common-Automation repo root (helper anchor)
#   repo_root              - the repo under check: the target repo named
#                            by COMMON_AUTOMATION_TARGET_REPO, else
#                            Common-Automation itself
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
common_automation_root="$(cd "${script_dir}/.." && pwd)"
repo_root="${COMMON_AUTOMATION_TARGET_REPO:-${common_automation_root}}"

# shellcheck source=./_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT
