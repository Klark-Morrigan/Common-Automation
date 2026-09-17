#!/usr/bin/env bats
# Tests for fix-trailing-whitespace.sh - the trim applied to Markdown and
# Gradle files. Each test drives a throwaway repo in BATS_TEST_TMPDIR, since
# the script reads its file set out of git rather than off the filesystem.
# Run with: bats lib/fix-trailing-whitespace.bats
#
# Every fixture states its whitespace as printf escapes - 'A line   \n', never
# a literal line break after the spaces. A suite about trailing whitespace is
# the one suite that cannot keep any in its own source: an editor trimming on
# save, or this very script run over the repo, would quietly rewrite the
# fixtures into files with nothing wrong with them, and the tests would pass
# while proving nothing.

source "${BATS_TEST_DIRNAME}/test-helpers/git-fixtures.bash"

setup() {
    require_git
    SCRIPT="${BATS_TEST_DIRNAME}/fix-trailing-whitespace.sh"

    new_git_repo
}

# Writes a tracked file from a printf format string, so a test can pin the
# exact bytes at the end of each line.
add_tracked_file() {
    local name="$1" content="$2"
    printf '%b' "${content}" > "${name}"
    git add "${name}"
}

@test "trims trailing whitespace from a tracked markdown file" {
    add_tracked_file notes.md 'A line   \n'

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = 'A line' ]
}

@test "trims a trailing tab as well as trailing spaces" {
    add_tracked_file notes.md 'A line\t\n'

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = 'A line' ]
}

@test "leaves a type no tier has claimed alone" {
    # Markdown is the only type the generic engine owns. A .gradle file is the
    # JVM tier's, and is trimmed only where that tier has widened the set.
    add_tracked_file build.gradle 'apply plugin: 3   \n'

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "$(cat build.gradle)" = "$(printf 'apply plugin: 3   ')" ]
}

@test "trims a type a tier has widened the set with" {
    add_tracked_file build.gradle 'apply plugin: 3   \n'

    # shellcheck source=./fix-trailing-whitespace.sh
    source "${SCRIPT}"
    WHITESPACE_TRIMMED_TYPES+=('*.gradle')

    run fix_trailing_whitespace
    [ "${status}" -eq 0 ]
    [ "$(cat build.gradle)" = 'apply plugin: 3' ]
}

@test "trims a whitespace-only line to empty" {
    add_tracked_file notes.md 'First\n   \nLast\n'

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = "$(printf 'First\n\nLast')" ]
}

@test "leaves a file type this rule does not own alone" {
    # Java is Spotless's and the JVM gate's business. Trimming it here would
    # give one file type two owners.
    add_tracked_file Main.java 'int x = 1;   \n'

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "$(cat Main.java)" = "$(printf 'int x = 1;   ')" ]
}

@test "leaves an untracked file alone" {
    printf 'stray   \n' > stray.md

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "$(cat stray.md)" = "$(printf 'stray   ')" ]
}

@test "is a silent no-op when nothing has trailing whitespace" {
    add_tracked_file clean.md 'A line\n'

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "keeps a carriage return at the end of a trimmed line" {
    # A repo that has not pinned LF checks Markdown out with CRLF. The trim
    # takes the spaces and leaves the line ending it found.
    add_tracked_file crlf.md 'A line   \r\n'

    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ "$(od -c < crlf.md | head -1 | tr -s ' ')" = "0000000 A l i n e \r \n" ]
}

@test "sourced fix trims only the paths it is given" {
    add_tracked_file asked.md 'Asked   \n'
    add_tracked_file spared.md 'Spared   \n'

    # shellcheck source=./fix-trailing-whitespace.sh
    source "${SCRIPT}"
    run fix_trailing_whitespace asked.md
    [ "${status}" -eq 0 ]
    [ "$(cat asked.md)" = 'Asked' ]
    [ "$(cat spared.md)" = "$(printf 'Spared   ')" ]
}

@test "sourced fix filters a mixed list down to the types it owns" {
    add_tracked_file notes.md 'A line   \n'
    add_tracked_file Main.java 'int x = 1;   \n'

    # shellcheck source=./fix-trailing-whitespace.sh
    source "${SCRIPT}"
    run fix_trailing_whitespace notes.md Main.java
    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = 'A line' ]
    [ "$(cat Main.java)" = "$(printf 'int x = 1;   ')" ]
}

@test "staged fix trims a staged file and re-stages it" {
    add_tracked_file notes.md 'A line   \n'

    # shellcheck source=./fix-trailing-whitespace.sh
    source "${SCRIPT}"
    run fix_staged_trailing_whitespace
    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = 'A line' ]
    # Nothing left unstaged: the trim went into the index, not beside it.
    git diff --quiet -- notes.md
}

@test "staged fix leaves a partly staged file for its author" {
    add_tracked_file notes.md 'Committed\n'
    git -c user.email=t@t -c user.name=t commit -qm 'first'

    printf 'Staged   \n' > notes.md
    git add notes.md
    printf 'Staged   \nUnstaged\n' > notes.md

    # shellcheck source=./fix-trailing-whitespace.sh
    source "${SCRIPT}"
    run fix_staged_trailing_whitespace
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"it has unstaged changes"* ]]
    # Untouched on both sides: the working tree keeps the author's line, and
    # the index keeps the whitespace rather than gaining the unstaged hunk.
    [ "$(cat notes.md)" = "$(printf 'Staged   \nUnstaged')" ]
    [ "$(git show :notes.md)" = "$(printf 'Staged   ')" ]
}
