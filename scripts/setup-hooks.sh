#!/usr/bin/env bash
#
# One-time per-clone setup.
#
# Wires the repo-checked-in hooks under .githooks/ into git
# so they actually fire on commit.
#
# Without this step,
# .git/hooks/ stays empty and the repo's defensive hooks
# (e.g. auto-+x on staged .sh files) do nothing.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The repo whose hooks get wired up.
#
# Defaults to this repo (Common-Automation);
# a consuming repo's thin setup-hooks.sh exports CONSUMER_REPO_PATH
# so the same one-time wiring applies to THAT repo -
# same single-source reuse as run-ci-yaml-and-bash.sh / fix-permissions.sh.
#
# The target supplies its own .githooks/
# (a thin pre-commit that delegates back here);
# this just points git at it.
#
repo_root="${CONSUMER_REPO_PATH:-$(cd "${script_dir}/.." && pwd)}"

# shellcheck source=SCRIPTDIR/_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT

# shellcheck source=SCRIPTDIR/../.github/lib/colors.sh
source "${script_dir}/../.github/lib/colors.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/fixes/executable-pathspecs.sh
source "${script_dir}/../.github/lib/fixes/executable-pathspecs.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/fixes/list-paths-missing-executable-bit.sh
source "${script_dir}/../.github/lib/fixes/list-paths-missing-executable-bit.sh"

# Idempotent:
# if this clone already points at .githooks there is nothing to wire,
# so say so and skip the redundant git config write.
current="$(git -C "${repo_root}" config --get core.hooksPath || true)"

if [[ "${current}" == ".githooks" ]]; then

    colorize green "No need - hooks have been configured already for ${repo_root}. core.hooksPath=.githooks"
    echo
else
    git -C "${repo_root}" config core.hooksPath .githooks

    colorize green "Hooks configured for ${repo_root}. core.hooksPath=.githooks"
    echo
    echo "Commits in this clone will now run .githooks/pre-commit."
fi

# A hook at mode 100644 is skipped on a Linux or WSL clone,
# with only a hint git prints once per commit,
# so every run names each one.
hooks_missing_executable_bit="$(cd "${repo_root}" \
    && list_paths_missing_executable_bit "${GIT_HOOK_PATHSPECS[@]}")"

if [[ -n "${hooks_missing_executable_bit}" ]]; then

    colorize yellow "These hooks lack +x in the git index, so a Linux or WSL clone skips them:"
    echo
    echo "${hooks_missing_executable_bit}"
    echo "Fix with: git update-index --chmod=+x <path>"
fi
