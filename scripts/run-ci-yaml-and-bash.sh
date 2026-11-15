#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154 (referenced but not assigned): script_dir and repo_root are set
# by the sourced _run-common.sh, which shellcheck cannot follow through the
# command-substitution source path.

# Local equivalent of the ci-yaml.yml, ci-markdown.yml and ci-bash.yml
# workflows: runs the lint half (_run-lint-yaml-and-bash.sh) and the
# bash-test half (_run-tests-bash.sh) against the target repo, then prints
# a combined pass/fail. Each half is a standalone script so a caller can
# run either in isolation; this orchestrator is the "run everything" entry
# that the per-repo run-ci-yaml-and-bash.sh shims mirror.

set -euo pipefail

# shellcheck source=SCRIPTDIR/_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=SCRIPTDIR/_run-recorded-check.sh
source "${script_dir}/_run-recorded-check.sh"

# shellcheck source=SCRIPTDIR/_report-check-summary.sh
source "${script_dir}/_report-check-summary.sh"

# Export so both halves resolve the same target even when this
# orchestrator defaulted repo_root to Common-Automation itself. Each
# half runs with the pause suppressed; this orchestrator owns the single
# hold-window pause via the EXIT trap armed above. `env` sets it for the
# half alone: exported here, it would silence that trap too.
export COMMON_AUTOMATION_TARGET_REPO="${repo_root}"

run_recorded_check "lint" \
    env COMMON_AUTOMATION_NO_PAUSE=1 \
    bash "${script_dir}/_run-lint-yaml-and-bash.sh"

run_recorded_check "bash tests" \
    env COMMON_AUTOMATION_NO_PAUSE=1 \
    bash "${script_dir}/_run-tests-bash.sh"

report_check_summary "all checks"
