#!/usr/bin/env bash
# Lists what a commit will carry, for the pre-commit fixes. Sourced, not
# executed: defines list_staged_paths.
#
# Every staged path except a deletion, renames and copies included. A file
# moved without git mv - by an editor, Explorer or Move-Item - is staged as a
# new index entry: on a Windows checkout it lands without +x, and it can carry
# edits of its own. Git reports such a move as a rename, so a filter on added
# and modified files would hand neither fix the file at all.
#
# Paths print as they are rather than C-quoted, so a name outside ASCII reaches
# the fixes as the file it names.

# Prints each staged path, repo-root-relative, one per line. Prints nothing
# when nothing is staged.
#   list_staged_paths
list_staged_paths() {

    git -c core.quotePath=false diff --cached --name-only --diff-filter=d
}
