#!/usr/bin/env bats
#
# Tests for
# list-files-with-trailing-whitespace.sh,
# the trim's detector.
#
# Each test drives a throwaway repo in BATS_TEST_TMPDIR,
# since the detector reads its file set out of git.
#
# Every fixture states its whitespace as a printf escape;
# git-fixtures.bash says why.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

# "cafe" with an acute e (U+0063 U+0061 U+0066 U+00E9), a name git C-quotes by
# default.
readonly NON_ASCII_NAME='café.md'

setup() {

    require_git
    new_git_repo

    # shellcheck source=SCRIPTDIR/list-files-with-trailing-whitespace.sh
    source "${BATS_TEST_DIRNAME}/list-files-with-trailing-whitespace.sh"
}

@test "names a tracked Markdown file with trailing spaces" {

    add_tracked_file notes.md 'A line   \n'
    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "${output}" = "notes.md" ]
}

@test "names a file with a trailing tab" {

    add_tracked_file notes.md 'A line\t\n'
    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "${output}" = "notes.md" ]
}

@test "leaves a clean file out" {

    add_tracked_file clean.md 'A line\n'
    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "leaves a type no tier has claimed out" {

    # Java is Spotless's business, and .gradle the JVM tier's.
    add_tracked_file Main.java 'int x = 1;   \n'
    add_tracked_file build.gradle 'apply plugin: 3   \n'

    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "names a type a tier has added" {

    add_tracked_file build.gradle 'apply plugin: 3   \n'
    WHITESPACE_TRIMMED_TYPES+=('*.gradle')

    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "${output}" = "build.gradle" ]
}

@test "leaves an untracked file out" {

    printf 'stray   \n' > stray.md
    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "skips a file that is binary despite its name" {

    add_tracked_file data.md 'A\0B   \n'
    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "narrows the scan to the paths given" {

    add_tracked_file asked.md 'Asked   \n'
    add_tracked_file spared.md 'Spared   \n'

    run list_files_with_trailing_whitespace asked.md

    [ "${status}" -eq 0 ]
    [ "${output}" = "asked.md" ]
}

@test "holds the paths given to the trimmed types" {

    add_tracked_file notes.md 'A line   \n'
    add_tracked_file Main.java 'int x = 1;   \n'

    run list_files_with_trailing_whitespace notes.md Main.java

    [ "${status}" -eq 0 ]
    [ "${output}" = "notes.md" ]
}

@test "is silent when given only paths of other types" {

    add_tracked_file Main.java 'int x = 1;   \n'
    run list_files_with_trailing_whitespace Main.java

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "reads a bracket in a given name literally" {

    # As a glob, a[1].md would also match a1.md.
    add_tracked_file 'a[1].md' 'Clean\n'
    add_tracked_file a1.md 'Offending   \n'

    run list_files_with_trailing_whitespace 'a[1].md'

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "names a path holding a space whole" {

    add_tracked_file 'my notes.md' 'A line   \n'
    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "${output}" = "my notes.md" ]
}

@test "names a file outside ASCII unquoted" {

    add_tracked_file "${NON_ASCII_NAME}" 'A line   \n'
    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "${output}" = "${NON_ASCII_NAME}" ]
}

@test "scans the whole repo when called from a subfolder" {

    add_tracked_file notes.md 'A line   \n'
    mkdir nested
    cd nested

    run list_files_with_trailing_whitespace

    [ "${status}" -eq 0 ]
    [ "${output}" = "notes.md" ]
}
