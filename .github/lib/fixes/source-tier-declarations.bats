#!/usr/bin/env bats
#
# Tests for
# source-tier-declarations.sh,
# which widens the family-wide sets from a tier's declaration files.
#
# Called directly rather than through run,
# since the sets it widens are the calling shell's.

setup() {

    # shellcheck source=SCRIPTDIR/source-tier-declarations.sh
    source "${BATS_TEST_DIRNAME}/source-tier-declarations.sh"

    TIER_FILE="${BATS_TEST_TMPDIR}/tier.sh"

    printf '%s\n' \
        "EXECUTABLE_PATHSPECS+=('gradlew')" \
        "WHITESPACE_TRIMMED_TYPES+=('*.gradle')" \
        > "${TIER_FILE}"
}

@test "widens both family-wide sets with a tier's declarations" {

    source_tier_declarations "${TIER_FILE}"

    [ "${EXECUTABLE_PATHSPECS[*]}" = '*.sh .githooks/* :(exclude).githooks/.* gradlew' ]
    [ "${WHITESPACE_TRIMMED_TYPES[*]}" = '*.md *.gradle' ]
}

@test "sources every declaration file given" {

    printf '%s\n' "WHITESPACE_TRIMMED_TYPES+=('*.kts')" > "${BATS_TEST_TMPDIR}/second.sh"
    source_tier_declarations "${TIER_FILE}" "${BATS_TEST_TMPDIR}/second.sh"

    [ "${WHITESPACE_TRIMMED_TYPES[*]}" = '*.md *.gradle *.kts' ]
}

@test "skips a declaration file that is absent" {

    source_tier_declarations /nowhere/tier.sh

    [ "${EXECUTABLE_PATHSPECS[*]}" = '*.sh .githooks/* :(exclude).githooks/.*' ]
    [ "${WHITESPACE_TRIMMED_TYPES[*]}" = '*.md' ]
}
