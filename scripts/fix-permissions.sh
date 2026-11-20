#!/usr/bin/env bash
#
# Repo-wide manual heal of the executable bit on the tracked files that must carry it:
# every *.sh and every git hook,
# plus whatever a tier declares on top.
#
# The pre-commit hook fixes only what a commit stages,
# and only in clones where setup-hooks.sh has been run.
# This runner covers the whole repo:
# the way to heal files that reached the index before the hook was wired up,
# or through a commit that skips hooks.
#
# A tier passes its declaration file as a positional argument,
# the same file its hook passes,
# so the set is never restated here.
#
#   fix-permissions.sh [tier_declaration_file...]

set -euo pipefail

# Resolves the repo to work on - CONSUMER_REPO_PATH, which a
# consuming repo's thin fix-permissions.sh exports, else this repo - and arms
# the keep-window-open pause for an Explorer double-click. Shared with the other
# entry points here so none of them can drift on either.
# shellcheck source=SCRIPTDIR/_run-common.sh disable=SC2312
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_run-common.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/fixes/fix-executable-bits.sh
source "${common_automation_root}/.github/lib/fixes/fix-executable-bits.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/fixes/source-tier-declarations.sh
source "${common_automation_root}/.github/lib/fixes/source-tier-declarations.sh"

# shellcheck source=SCRIPTDIR/_print-fix-outcome.sh
source "${script_dir}/_print-fix-outcome.sh"

source_tier_declarations "$@"

print_section_heading "fixing +x on tracked files (${EXECUTABLE_PATHSPECS[*]}) in ${repo_root}"

# Run inside the repo under check, since the fix finds its repo from the current folder.
# Captured so an empty result reads as "nothing to fix";
# the index changes persist regardless.
fixed="$(cd "${repo_root}" && fix_executable_bits)"

print_fix_outcome "${fixed}" "git status" \
    "Nothing to fix - every tracked file that must be executable already is."
