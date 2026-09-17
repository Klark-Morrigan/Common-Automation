#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154 (referenced but not assigned): repo_root and common_automation_root
# are set by the sourced _run-common.sh, which shellcheck cannot follow through
# a command-substitution source path.

# Repo-wide manual fix for the executable bit on tracked files that must
# carry +x: every *.sh (the family-wide rule) and every .githooks/ script.
# Both are needed on a fresh Linux clone - .sh files for direct execution,
# the hooks so they fire at all - and both land mode 0644 when authored on
# Windows. .githooks/ scripts carry no .sh extension, so the *.sh-only CI
# gate (check-sh-executable) never flags them; healing them here is the only
# automatic guard they get.
#
# The pre-commit hook only fixes files in a given commit, and only in
# clones where setup-hooks.sh has been run. This runner re-stages +x
# across the whole repo - the way to heal files that slipped in before the
# hook existed or was installed.
#
# Consumers that need a wider set still (e.g. a Java repo's gradlew, which
# has no .sh extension) pass the extra pathspecs as positional args; they
# widen the shared default set, they do not replace it. This is the single
# source of that default set so consumers need not restate '*.sh'/'.githooks/*'.
#
# Reuses the shared fix engine (.github/lib/fix-sh-executable.sh) so
# the manual path and the hook apply an identical fix.

set -euo pipefail

# Resolves the repo to work on - COMMON_AUTOMATION_TARGET_REPO, which a
# consuming repo's thin fix-permissions.sh exports, else this repo - and arms
# the keep-window-open pause for an Explorer double-click. Shared with the other
# entry points here so none of them can drift on either.
# shellcheck source=./_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=../.github/lib/fix-sh-executable.sh
source "${common_automation_root}/.github/lib/fix-sh-executable.sh"

# colorize for this runner's own status line. The engine sources colors.sh
# too, but depend on it explicitly here since we call colorize directly.
# shellcheck source=../.github/lib/colors.sh
source "${common_automation_root}/.github/lib/colors.sh"

# fix_sh_executable resolves the git toplevel from the current dir, so run
# it inside the target repo to scope the fix there. Its stdout is captured
# so this runner can tell "nothing needed fixing" (empty) from "fixed N
# files" and report each differently - the index changes (git update-index)
# happen as a side effect and persist regardless of the capture. colorize's
# enable decision was fixed when colors.sh was sourced above, so the green
# of the per-file lines survives this command substitution.
# Shared default set every repo heals (*.sh + git hooks), plus any extra
# pathspecs a consumer appended via positional args (e.g. gradlew). Building
# one array keeps the status line and the fix call in lockstep.
#
# The .githooks/ exclude keeps dotfiles (.gitignore, .keep) non-executable:
# real git hooks are named without a leading dot (pre-commit, pre-push, ...),
# so a bare .githooks/* would wrongly +x repo config that lives beside them.
pathspecs=('*.sh' '.githooks/*' ':(exclude).githooks/.*' "$@")

echo "=== fixing +x on tracked files (${pathspecs[*]}) in ${repo_root} ==="
fixed="$(cd "${repo_root}" && fix_sh_executable "${pathspecs[@]}")"
if [[ -n "${fixed}" ]]; then
    echo "${fixed}"
    echo "Done. Review staged mode changes with: git status"
else
    clean_msg="$(colorize green "Nothing to fix - all tracked files already have +x.")"
    echo "${clean_msg}"
fi
