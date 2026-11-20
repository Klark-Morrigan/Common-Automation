#!/usr/bin/env bats
#
# Tests for
# trimmed-file-types.sh,
# the family-wide set of trimmed text types.

@test "declares Markdown" {

    # shellcheck source=SCRIPTDIR/trimmed-file-types.sh
    source "${BATS_TEST_DIRNAME}/trimmed-file-types.sh"

    [ "${WHITESPACE_TRIMMED_TYPES[*]}" = '*.md' ]
}

@test "keeps a tier's types when sourced again" {

    # shellcheck source=SCRIPTDIR/trimmed-file-types.sh
    source "${BATS_TEST_DIRNAME}/trimmed-file-types.sh"
    WHITESPACE_TRIMMED_TYPES+=('*.gradle')

    # shellcheck source=SCRIPTDIR/trimmed-file-types.sh
    source "${BATS_TEST_DIRNAME}/trimmed-file-types.sh"

    [ "${WHITESPACE_TRIMMED_TYPES[*]}" = '*.md *.gradle' ]
}
