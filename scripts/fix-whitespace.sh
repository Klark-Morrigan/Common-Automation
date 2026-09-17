#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154 (referenced but not assigned): repo_root and common_automation_root
# are set by the sourced _run-common.sh, and WHITESPACE_TRIMMED_TYPES by the
# sourced trim engine - none of which shellcheck can follow, one being sourced
# through a command substitution and the others through a variable path.

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

# Resolves the repo to work on - COMMON_AUTOMATION_TARGET_REPO, which a
# consuming repo's thin shim exports, else this repo - and arms the
# keep-window-open pause for an Explorer double-click. Shared with the other
# entry points here so none of them can drift on either.
# shellcheck source=./_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=../.github/lib/fix-trailing-whitespace.sh
source "${common_automation_root}/.github/lib/fix-trailing-whitespace.sh"

# colorize for this runner's own status line. The engine sources colors.sh too,
# but depend on it explicitly here since we call colorize directly.
# shellcheck source=../.github/lib/colors.sh
source "${common_automation_root}/.github/lib/colors.sh"

source_declared_file_types "$@"

# fix_trailing_whitespace resolves the git toplevel from the current directory,
# so run it inside the target repo to scope the trim there. Its stdout is
# captured so this runner can tell "nothing needed trimming" (empty) from
# "trimmed N files" and report each differently - the rewrites happen as a side
# effect and persist regardless of the capture. colorize's enable decision was
# fixed when colors.sh was sourced above, so the green of the per-file lines
# survives this command substitution.
echo "=== trimming trailing whitespace on tracked files (${WHITESPACE_TRIMMED_TYPES[*]}) in ${repo_root} ==="
trimmed="$(cd "${repo_root}" && fix_trailing_whitespace)"
if [[ -n "${trimmed}" ]]; then
    echo "${trimmed}"
    echo "Done. Review the rewrites with: git diff"
else
    clean_msg="$(colorize green "Nothing to fix - no tracked file ends a line in whitespace.")"
    echo "${clean_msg}"
fi
