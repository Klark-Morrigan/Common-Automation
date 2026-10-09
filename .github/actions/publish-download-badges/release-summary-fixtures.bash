#!/usr/bin/env bash
# Shared release-summary fixtures for this action's bats suites. Sourced -
# never run - so it carries no tests itself and is skipped by the recursive
# *.bats runner.
#
# summarise-release-downloads.sh prints the summary and every renderer reads
# it, so the suites on both sides build its lines here, from one statement of
# the format.

# Builds one summary line, without its newline:
#   build_summary_line <tag> <published_at> <download count>
build_summary_line() {

    printf '%s\t%s\t%s' "$1" "$2" "$3"
}
