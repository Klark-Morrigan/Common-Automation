#!/usr/bin/env bash
#
# shellcheck disable=SC2034 # read by the files that source this
#
# What counts as trailing whitespace, as one POSIX basic regular expression
# shared by the detector and the trim, so the two cannot disagree.
#
# Sourced, not executed.
#
# Space and tab only.
# A trailing CR is captured rather than eaten,
# so a file checked out with CRLF keeps its line endings.
#
# The tab and the CR are real characters, written with $'...':
# a basic regular expression has no \t or \r escape,
# so grep and sed would read them as the letters t and r.
#
TRAILING_WHITESPACE_PATTERN=$'[ \t]\\{1,\\}\\(\r\\{0,1\\}\\)$'
