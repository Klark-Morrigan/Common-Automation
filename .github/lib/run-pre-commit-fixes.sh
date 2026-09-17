#!/usr/bin/env bash
# The body of every repo's pre-commit hook: which fixes a commit gets, in what
# order, and over which part of what is staged.
#
# Why this is shared rather than written per repo. Five repos carried the same
# four steps - resolve the sibling engines, collect the staged files needing
# +x, apply that fix, trim trailing whitespace - and differed in one regex. Two
# of them had already drifted: one kept an older +x set, and the one added last
# carried a fix the others did not. A hook is the worst place for that kind of
# drift, because the repo where it is wrong is the repo nobody notices until a
# runner rejects the commit.
#
# What stays in each repo's own hook is only what that repo alone knows: where
# its sibling checkouts are, which paths it needs +x on, and which tier it
# belongs to. Git wants a hook file per repo, so that much is irreducible.
#
# Signature:
#
#   run_pre_commit_fixes [executable_pathspec_regex] [tier_type_file...]
#
#   executable_pathspec_regex  which staged paths must carry +x, as an ERE.
#                              Defaults to *.sh, the family-wide rule; a repo
#                              with unextensioned executables (gradlew, git
#                              hooks) passes a wider one.
#   tier_type_file             a file declaring further text types to trim, for
#                              a tier that owns some - the JVM tier's .gradle,
#                              say. Sourced when present and ignored when not,
#                              so a clone missing that sibling still commits.

set -euo pipefail

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The two fixes themselves. Sourced rather than executed so they act on what is
# staged rather than walking the whole repo.
# shellcheck source=fix-sh-executable.sh
source "${lib_dir}/fix-sh-executable.sh"
# shellcheck source=fix-trailing-whitespace.sh
source "${lib_dir}/fix-trailing-whitespace.sh"

# The family-wide +x rule, for a repo that names no wider one.
DEFAULT_EXECUTABLE_PATHSPEC_REGEX='\.sh$'

run_pre_commit_fixes() {

    local executable_pathspec_regex="${1:-${DEFAULT_EXECUTABLE_PATHSPEC_REGEX}}"
    local types_file staged
    local -a staged_paths

    if (( $# > 0 )); then
        shift
    fi

    # Text types beyond the generic engine's own, where the tier declaring them
    # is checked out. Absent is not a failure: the commit is still trimmed for
    # the types every repo shares, which is better than refusing to commit.
    for types_file in "$@"; do
        if [[ -f "${types_file}" ]]; then
            # shellcheck source=/dev/null
            source "${types_file}"
        fi
    done

    # --diff-filter=AM picks up Added and Modified files. Renames keep their
    # previous mode, so a `git mv` from a +x dir does not need fixing.
    staged="$(git diff --cached --name-only --diff-filter=AM | grep -E "${executable_pathspec_regex}" || true)"

    # Passed as args so only what is being committed is touched, never an
    # unrelated tracked file. fix_sh_executable checks exactly these paths
    # whatever their extension, so gradlew and the hooks are handled like .sh.
    if [[ -n "${staged}" ]]; then
        readarray -t staged_paths <<< "${staged}"
        fix_sh_executable "${staged_paths[@]}"
    fi

    # No staged set is computed for this one: the engine reads the staged list
    # itself and picks its own file types out of it, so nothing here carries a
    # second copy of which types get trimmed.
    fix_staged_trailing_whitespace
}

# Sourced? Expose the function and return - skip the run.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

run_pre_commit_fixes "$@"
