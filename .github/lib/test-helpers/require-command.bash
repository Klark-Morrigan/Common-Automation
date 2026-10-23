#!/usr/bin/env bash
# Shared guard for the bats cases that need a real tool rather than a stub.
# Sourced - never run - so it carries no tests itself and is skipped by the
# recursive *.bats runner.
#
# A missing tool belongs to the workstation, not to the script under test, so
# the case skips rather than fails: Git Bash on Windows has no shellcheck, and
# the git-less bats Docker image has no git. Stated here once so every suite
# skips the same way and says why.

# Skips the calling test when <command> is not on PATH.
#   require_command <command>
require_command() {

    command -v "$1" > /dev/null 2>&1 || skip "$1 not on PATH"
}
