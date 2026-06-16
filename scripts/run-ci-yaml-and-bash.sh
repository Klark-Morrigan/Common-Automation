#!/usr/bin/env bash
# shellcheck disable=SC2310,SC2154
# SC2310: each half runs from `if !` so a lint failure still lets the
# bats half run, and both report in one pass.
# SC2154 (referenced but not assigned): script_dir,
# common_automation_root and repo_root are set by the sourced
# _run-common.sh, which shellcheck cannot follow through the
# command-substitution source path.

# Local equivalent of the ci-yaml.yml + ci-bash.yml workflows: runs the
# lint half (_run-lint-yaml-and-bash.sh) and the bash-test half
# (_run-tests-bash.sh) against the target repo, then prints a combined
# pass/fail. Each half is a standalone script so a caller can run either
# in isolation; this orchestrator is the "run everything" entry that the
# per-repo run-ci-yaml-and-bash.sh shims mirror.

set -euo pipefail

# shellcheck source=./_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# Export so both halves resolve the same target even when this
# orchestrator defaulted repo_root to Common-Automation itself. Each
# half runs with the pause suppressed; this orchestrator owns the single
# hold-window pause via the EXIT trap armed above.
export COMMON_AUTOMATION_TARGET_REPO="${repo_root}"

failures=()

if ! COMMON_AUTOMATION_NO_PAUSE=1 bash "${script_dir}/_run-lint-yaml-and-bash.sh"; then
    failures+=("lint")
fi
echo

if ! COMMON_AUTOMATION_NO_PAUSE=1 bash "${script_dir}/_run-tests-bash.sh"; then
    failures+=("bash-tests")
fi
echo

if (( ${#failures[@]} > 0 )); then
    echo "FAILED: ${failures[*]}" >&2
    exit 1
fi
echo "All checks passed."
