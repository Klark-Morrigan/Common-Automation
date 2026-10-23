#!/usr/bin/env bats
# Unit tests for resolve-display-text.sh.
# Run with: bats .github/lib/log-records/presenters/resolve-display-text.bats

# shellcheck source=SCRIPTDIR/resolve-display-text.sh
source "${BATS_TEST_DIRNAME}/resolve-display-text.sh"

@test "upper-cases a locale" {

    resolve_display_text locale "zh-hans"

    [ "${display_text}" = "ZH-HANS" ]
}

@test "keeps any other role's text as written" {

    resolve_display_text id "KMU-0.2.0-en.zip"

    [ "${display_text}" = "KMU-0.2.0-en.zip" ]
}

@test "keeps plain text as written" {

    resolve_display_text "" "Reading en"

    [ "${display_text}" = "Reading en" ]
}
