#!/usr/bin/env bash
# shellcheck disable=SC2154
# SC2154 (referenced but not assigned): repo_root and common_automation_root
# are set by the sourced _run-common.sh, and WHITESPACE_TRIMMED_TYPES by the
# sourced declarations - none of which shellcheck can follow, one being sourced
# through a command substitution and the others through a variable path.
#
# Repo-wide manual trim of trailing whitespace in the text files no formatter owns:
# Markdown, plus whatever a tier declares on top.
#
# The pre-commit hook trims only what a commit stages,
# and only in clones where setup-hooks.sh has been run.
# This runner covers the whole repo:
# the way to heal files that slipped in before the hook was wired up,
# and the way to fix a file the hook left alone
# because it had unstaged changes at the time.
#
# A tier passes its declaration file as a positional argument,
# the same file its hook passes,
# so the set is never restated here.
#
#   fix-whitespace.sh [tier_declaration_file...]

set -euo pipefail

# Resolves the repo to work on - CONSUMER_REPO_PATH, which a
# consuming repo's thin shim exports, else this repo - and arms the
# keep-window-open pause for an Explorer double-click. Shared with the other
# entry points here so none of them can drift on either.
# shellcheck source=SCRIPTDIR/_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/fixes/fix-trailing-whitespace.sh
source "${common_automation_root}/.github/lib/fixes/fix-trailing-whitespace.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/fixes/source-tier-declarations.sh
source "${common_automation_root}/.github/lib/fixes/source-tier-declarations.sh"

# shellcheck source=SCRIPTDIR/_print-fix-outcome.sh
source "${script_dir}/_print-fix-outcome.sh"

source_tier_declarations "$@"

print_section_heading "trimming trailing whitespace on tracked files (${WHITESPACE_TRIMMED_TYPES[*]}) in ${repo_root}"

# Run inside the repo under check, since the fix finds its repo from the current folder.
# Captured so an empty result reads as "nothing to fix";
# the rewrites persist regardless.
trimmed="$(cd "${repo_root}" && fix_trailing_whitespace)"

print_fix_outcome "${trimmed}" "git diff" \
    "Nothing to fix - no tracked file ends a line in whitespace."
