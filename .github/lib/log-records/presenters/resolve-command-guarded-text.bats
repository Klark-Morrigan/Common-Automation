#!/usr/bin/env bats
# Unit tests for resolve-command-guarded-text.sh.
# Run with: bats .github/lib/log-records/presenters/resolve-command-guarded-text.bats

# shellcheck source=SCRIPTDIR/resolve-command-guarded-text.sh
source "${BATS_TEST_DIRNAME}/resolve-command-guarded-text.sh"

readonly GUARD=$'\033[0m'

@test "breaks a :: the text starts with" {

    resolve_command_guarded_text "::stop-commands::token"

    [ "${command_guarded_text}" = ":${GUARD}:stop-commands::token" ]
}

@test "breaks a :: after leading whitespace, which the runner skips" {

    resolve_command_guarded_text $'  \t::add-mask::x'

    [ "${command_guarded_text}" = $'  \t:'"${GUARD}"':add-mask::x' ]
}

@test "leaves a :: past the start alone, where the runner does not look" {

    resolve_command_guarded_text "KMU::0.2.0"

    [ "${command_guarded_text}" = "KMU::0.2.0" ]
}

@test "breaks every ##[ wherever it sits" {

    resolve_command_guarded_text "a ##[error]b ##[group]c"

    [ "${command_guarded_text}" = "a #${GUARD}#[error]b #${GUARD}#[group]c" ]
}

@test "leaves a text with no marker unchanged" {

    resolve_command_guarded_text "KMU-0.2.0-en.zip"

    [ "${command_guarded_text}" = "KMU-0.2.0-en.zip" ]
}
