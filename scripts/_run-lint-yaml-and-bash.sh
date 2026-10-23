#!/usr/bin/env bash
# shellcheck disable=SC2310,SC2154
# SC2310 (set -e disabled inside functions called from `if !`) is
# intentional here: each check is invoked from `if ! foo; then` so its
# failure is tracked rather than terminating the script - we want every
# check to report, the same way CI's parallel jobs all fire.
# SC2154 (referenced but not assigned): common_automation_root and
# repo_root are set by the sourced _run-common.sh, which shellcheck cannot
# follow through the command-substitution source path.

# Lint half of the local CI suite, run against the target repo:
#
#   - shellcheck (production bash under .github)
#   - shellcheck (runner bash under scripts/)
#   - shellcheck (domain bash anywhere else)
#   - shellcheck (git hooks under .githooks/)
#   - check-sh-executable (+x bit on every tracked *.sh)
#   - actionlint (every workflow)
#   - action-validator (every workflow + composite action.yml)
#   - yamllint (plain YAML outside the actionlint/action-validator surface)
#
# This is the lint half of ci-yaml.yml plus the shellcheck /
# check-sh-executable jobs of ci-bash.yml; bats (the test half) lives in
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

# Runs one composite action's helper script from the target repo's root,
# the way its CI job runs it, under a heading naming the check.
#   run_action_helper <heading> <action name> [helper argument...]
run_action_helper() {

    local heading="$1"
    local action_name="$2"
    local helper="${common_automation_root}/.github/actions/${action_name}/${action_name}.sh"

    shift 2

    echo "=== ${heading} ==="

    (cd "${repo_root}" && bash "${helper}" "$@")
}

# Track failures so a shellcheck miss in production does not short-
# circuit before the later checks also report. Same shape as CI's
# parallel jobs - the user sees every problem in one run. `if ! foo;
# then ... fi` (rather than `foo || ...`) is used so set -e stays active
# inside each function.
failures=()

if ! run_action_helper "shellcheck production (.github)" shellcheck-bash .github; then
    failures+=("shellcheck-production")
fi
echo

if ! run_action_helper "shellcheck runners (scripts)" shellcheck-bash scripts; then
    failures+=("shellcheck-runners")
fi
echo

# Domain bash: the repo's own production bash outside .github/scripts
# (e.g. ops/). Scan-by-exclusion mirrors the ci-bash shellcheck-domain
# job so a new production directory is gated automatically. The excludes
# match that job verbatim - the trees already covered by another check
# (.github, scripts, .githooks), the test suites (Tests/tests), and
# vendored or CI-injected trees (.venv, node_modules, .common-automation,
# .git) - so local and CI cannot drift.
if ! run_action_helper "shellcheck domain (.)" shellcheck-bash . \
        .git .github scripts Tests tests .venv node_modules .common-automation .githooks; then
    failures+=("shellcheck-domain")
fi
echo

if ! run_action_helper "shellcheck hooks (.githooks)" shellcheck-hooks; then
    failures+=("shellcheck-hooks")
fi
echo

if ! run_action_helper "check-sh-executable" check-sh-executable; then
    failures+=("check-sh-executable")
fi
echo

if ! run_action_helper "actionlint" actionlint; then
    failures+=("actionlint")
fi
echo

if ! run_action_helper "action-validator" action-validator; then
    failures+=("action-validator")
fi
echo

if ! run_action_helper "yamllint" yamllint; then
    failures+=("yamllint")
fi
echo

if (( ${#failures[@]} > 0 )); then

    echo "FAILED (lint): ${failures[*]}" >&2
    exit 1
fi
echo "Lint checks passed."
