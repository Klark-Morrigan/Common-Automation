#!/usr/bin/env bash
#
# The body of every repo's pre-commit hook:
# which fixes a commit gets, and in what order.
#
# Sourced, not executed: defines run_pre_commit_fixes.
#
# Shared so every repo fixes a commit the same way.
# A copy that drifts is wrong in the repo nobody watches,
# until a runner rejects the commit.
#
# Each repo's own hook keeps only what that repo alone knows:
# where its sibling checkouts are,
# and which tier declarations widen the family-wide sets.

# shellcheck source=SCRIPTDIR/fix-staged-executable-bits.sh
source "${BASH_SOURCE[0]%/*}/fix-staged-executable-bits.sh"

# shellcheck source=SCRIPTDIR/fix-staged-trailing-whitespace.sh
source "${BASH_SOURCE[0]%/*}/fix-staged-trailing-whitespace.sh"

# shellcheck source=SCRIPTDIR/source-tier-declarations.sh
source "${BASH_SOURCE[0]%/*}/source-tier-declarations.sh"

# A declaration file widens EXECUTABLE_PATHSPECS and WHITESPACE_TRIMMED_TYPES,
# as the JVM tier's do with gradlew and *.gradle.
# One that is absent is skipped, so a clone missing that sibling still commits.
#
#   run_pre_commit_fixes [tier_declaration_file...]
run_pre_commit_fixes() {

    source_tier_declarations "$@"

    fix_staged_executable_bits
    fix_staged_trailing_whitespace
}
