#!/usr/bin/env bash
#
# shellcheck disable=SC2034 # read by the files that source this
#
# The text types every repo in the family trims trailing whitespace from,
# as git pathspecs.
#
# Sourced, not executed.
#
# Markdown is the one type every repo has, whatever it is written in.
# Two trailing spaces are a hard line break in Markdown;
# no file in this family uses them,
# since the house style breaks lines at punctuation instead.
#
# A tier with text types of its own appends to WHITESPACE_TRIMMED_TYPES
# in its declaration file, such as Common-Java's *.gradle.

# Declared only when unset,
# so sourcing this again after a tier widened the set
# cannot drop the tier's types.
if [[ ! -v WHITESPACE_TRIMMED_TYPES ]]; then
    WHITESPACE_TRIMMED_TYPES=('*.md')
fi
