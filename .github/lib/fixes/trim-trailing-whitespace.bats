#!/usr/bin/env bats
#
# Tests for
# trim-trailing-whitespace.sh,
# which rewrites the files given.
#
# Every fixture states its whitespace as a printf escape;
# git-fixtures.bash says why.

# shellcheck source=SCRIPTDIR/../test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../test-helpers/git-fixtures.bash"

setup() {

    require_git
    new_git_repo

    # shellcheck source=SCRIPTDIR/trim-trailing-whitespace.sh
    source "${BATS_TEST_DIRNAME}/trim-trailing-whitespace.sh"
}

@test "trims trailing spaces and tabs" {

    add_tracked_file notes.md 'Spaces   \nTab\t\n'
    run trim_trailing_whitespace notes.md

    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = "$(printf 'Spaces\nTab')" ]
}

@test "trims a whitespace-only line to empty" {

    add_tracked_file notes.md 'First\n   \nLast\n'
    run trim_trailing_whitespace notes.md

    [ "${status}" -eq 0 ]
    [ "$(cat notes.md)" = "$(printf 'First\n\nLast')" ]
}

@test "keeps a carriage return at the end of a trimmed line" {

    # A repo that has not pinned LF checks Markdown out with CRLF.
    add_tracked_file crlf.md 'A line   \r\n'
    run trim_trailing_whitespace crlf.md

    [ "${status}" -eq 0 ]
    [ "$(od -c < crlf.md | head -1 | tr -s ' ')" = "0000000 A l i n e \r \n" ]
}

@test "trims every file given and names each" {

    add_tracked_file first.md 'One   \n'
    add_tracked_file 'second one.md' 'Two   \n'

    run trim_trailing_whitespace first.md 'second one.md'

    [ "${status}" -eq 0 ]
    [ "$(cat first.md)" = 'One' ]
    [ "$(cat 'second one.md')" = 'Two' ]
    [ "${output}" = "$(printf 'trimming trailing whitespace in first.md\ntrimming trailing whitespace in second one.md')" ]
}

@test "leaves a file it is not given alone" {

    add_tracked_file asked.md 'Asked   \n'
    add_tracked_file spared.md 'Spared   \n'

    run trim_trailing_whitespace asked.md

    [ "${status}" -eq 0 ]
    [ "$(cat spared.md)" = "$(printf 'Spared   ')" ]
}

@test "reads the paths from the repo top when called from a subfolder" {

    add_tracked_file notes.md 'A line   \n'
    mkdir nested
    cd nested

    run trim_trailing_whitespace notes.md

    [ "${status}" -eq 0 ]
    [ "$(cat ../notes.md)" = 'A line' ]
}
