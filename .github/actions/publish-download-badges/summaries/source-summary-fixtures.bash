#!/usr/bin/env bash
# Shared source-summary fixtures for this action's bats suites. Sourced -
# never run - so it carries no tests itself, and it is not a *.bats file, so no
# bats run takes it for a suite.
#
# The sources print these lines and the stages after them read them, so the
# suites on both sides build them here. source-summary.bats checks these
# lines against source-summary.sh's format.

# Builds one source summary line, without its newline:
#   build_source_summary_line <version> <locale> <download count>
build_source_summary_line() {

    printf '%s\t%s\t%s' "$1" "$2" "$3"
}
