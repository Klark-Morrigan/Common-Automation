#!/usr/bin/env bash
# Shared source-summary fixtures for this action's bats suites. Sourced -
# never run - so it carries no tests itself and is skipped by the recursive
# *.bats runner.
#
# The sources print these lines and the stages after them read them, so the
# suites on both sides build them here. source-summary.bats checks these
# lines against source-summary.sh's format.

# Builds one source summary line, without its newline:
#   build_source_summary_line <version> <locale> <download count>
build_source_summary_line() {

    printf '%s\t%s\t%s' "$1" "$2" "$3"
}
