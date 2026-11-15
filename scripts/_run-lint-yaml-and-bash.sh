#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154 (referenced but not assigned): common_automation_root and
# repo_root are set by the sourced _run-common.sh, which shellcheck cannot
# follow through the command-substitution source path.

# Lint half of the local CI suite, run against the target repo: the checks
# of ci-yaml.yml and ci-markdown.yml plus the shellcheck /
# check-sh-executable jobs of ci-bash.yml. bats (the test half) lives in
# _run-tests-bash.sh, and run-ci-yaml-and-bash.sh runs both. Underscore-
# prefixed because it is a building block invoked by that orchestrator
# and by the per-repo run-lint-yaml-and-bash.sh shims, not a standalone
# entry name.
#
# Every check runs the same helper script its CI job runs, so discovery,
# flags and pinned images cannot drift between CI and here. The helpers
# fall back to Docker themselves where a tool is missing, so a developer
# with only Docker Desktop on Windows still gets a working pre-push check.

set -euo pipefail

# shellcheck source=SCRIPTDIR/_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=SCRIPTDIR/_run-recorded-check.sh
source "${script_dir}/_run-recorded-check.sh"

# shellcheck source=SCRIPTDIR/_report-check-summary.sh
source "${script_dir}/_report-check-summary.sh"

actions_dir="${common_automation_root}/.github/actions"

# Each helper runs from the target repo's root, as its CI job does.
cd "${repo_root}"

run_recorded_check "shellcheck production (.github)" \
    bash "${actions_dir}/shellcheck-bash/shellcheck-bash.sh" \
    .github

run_recorded_check "shellcheck runners (scripts)" \
    bash "${actions_dir}/shellcheck-bash/shellcheck-bash.sh" \
    scripts

# Domain bash: the repo's own production bash outside .github/scripts
# (e.g. ops/). Scan-by-exclusion mirrors the ci-bash shellcheck-domain
# job so a new production directory is gated automatically. The excludes
# match that job verbatim - the trees already covered by another check
# (.github, scripts, .githooks), the test suites (Tests/tests), and
# vendored or CI-injected trees (.venv, node_modules, .common-automation,
# .git) - so local and CI cannot drift.
run_recorded_check "shellcheck domain (.)" \
    bash "${actions_dir}/shellcheck-bash/shellcheck-bash.sh" . \
    .git .github scripts Tests tests .venv node_modules .common-automation .githooks

run_recorded_check "shellcheck hooks (.githooks)" \
    bash "${actions_dir}/shellcheck-hooks/shellcheck-hooks.sh"

run_recorded_check "check-sh-executable" \
    bash "${actions_dir}/check-sh-executable/check-sh-executable.sh"

run_recorded_check "actionlint" \
    bash "${actions_dir}/actionlint/actionlint.sh"

run_recorded_check "action-validator" \
    bash "${actions_dir}/action-validator/action-validator.sh"

run_recorded_check "yamllint" \
    bash "${actions_dir}/yamllint/yamllint.sh"

run_recorded_check "markdownlint" \
    bash "${actions_dir}/markdownlint/markdownlint.sh"

report_check_summary "lint checks"
