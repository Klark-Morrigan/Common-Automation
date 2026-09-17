#!/usr/bin/env bash
# Repo-wide manual trim of trailing whitespace in the text files no formatter
# owns - Markdown here, plus whatever a tier declares on top.
#
# The pre-commit hook only trims the files a given commit touches, and only in
# clones where setup-hooks.sh has been run. This runner covers the whole repo:
# the way to heal files that slipped in before the hook existed or was
# installed, and the way to fix a path the hook deliberately left alone because
# it had unstaged changes at the time.
#
# Consumers that own further text types pass the file declaring them as
# positional args - the same file their hook passes - so the set is never
# restated here. A tier's declaration that is not checked out is skipped rather
# than fatal; the engine owns that rule, since the hook has to answer it the
# same way.
#
# Reuses the shared engine (.github/lib/fix-trailing-whitespace.sh) so the
# manual path and the hook apply an identical trim.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The repo whose tracked files get trimmed. Defaults to this repo
# (Common-Automation); a consuming repo's thin fix-whitespace.sh exports
# COMMON_AUTOMATION_TARGET_REPO so the shared engine heals THAT repo instead -
# same single-source reuse as fix-permissions.sh.
target_repo="${COMMON_AUTOMATION_TARGET_REPO:-$(cd "${script_dir}/.." && pwd)}"

# Keep the window open on an Explorer double-click (no-op under the .bat
# launcher, which sets COMMON_AUTOMATION_NO_PAUSE=1, and in CI/pipes).
# shellcheck source=./_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT

# shellcheck source=../.github/lib/fix-trailing-whitespace.sh
source "${script_dir}/../.github/lib/fix-trailing-whitespace.sh"

# colorize for this runner's own status line. The engine sources colors.sh too,
# but depend on it explicitly here since we call colorize directly.
# shellcheck source=../.github/lib/colors.sh
source "${script_dir}/../.github/lib/colors.sh"

source_declared_file_types "$@"

# fix_trailing_whitespace resolves the git toplevel from the current directory,
# so run it inside the target repo to scope the trim there. Its stdout is
# captured so this runner can tell "nothing needed trimming" (empty) from
# "trimmed N files" and report each differently - the rewrites happen as a side
# effect and persist regardless of the capture. colorize's enable decision was
# fixed when colors.sh was sourced above, so the green of the per-file lines
# survives this command substitution.
#
# The type set is assigned by the engine sourced above, and widened by any
# declaration sourced after it. shellcheck cannot follow a source path built
# from a variable, so from here the array reads as never assigned.
# shellcheck disable=SC2154
echo "=== trimming trailing whitespace on tracked files (${WHITESPACE_TRIMMED_TYPES[*]}) in ${target_repo} ==="
trimmed="$(cd "${target_repo}" && fix_trailing_whitespace)"
if [[ -n "${trimmed}" ]]; then
    echo "${trimmed}"
    echo "Done. Review the rewrites with: git diff"
else
    clean_msg="$(colorize green "Nothing to fix - no tracked file ends a line in whitespace.")"
    echo "${clean_msg}"
fi
