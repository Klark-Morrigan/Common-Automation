#!/usr/bin/env bats
# Unit tests for create-github-release.sh.
# Run with: bats .github/actions/create-github-release/create-github-release.bats

# shellcheck source=../../lib/test-helpers/gh-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/gh-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/create-github-release.sh"

setup() {

    # Left at its defaults, the stub records the arguments and succeeds.
    install_gh_stub

    export CHANGELOG="${BATS_TEST_TMPDIR}/CHANGELOG.md"

    cat > "${CHANGELOG}" <<'MD'
# Changelog

## [Unreleased]

## [8.1.0] - 2026-06-14

### Added
- Exit-code retry helper.
- A second bullet.

## [8.0.0] - 2026-06-13

### Changed
- An older change.
MD

    # Clear the input env so each test sets only what it needs.
    unset VERSION TAG DRAFT PRERELEASE FILES NOTES_SUFFIX
    export GH_TOKEN="stub-token"
}

@test "auto-detects the latest version, skipping Unreleased" {

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    # Tag and title are both the detected version.
    grep -qx '8.1.0' "${GH_ARGS_FILE}"

    [[ "$(cat "${GH_ARGS_FILE}")" != *"Unreleased"* ]]
}

@test "passes the changelog section as the notes body" {

    # Section parsing itself is covered by .github/lib/changelog.bats; here
    # we only confirm the action threads that body through to gh.
    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(cat "${GH_ARGS_FILE}")" == *"Exit-code retry helper."* ]]
}

@test "passes the expected gh subcommand and flags" {

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    # Whole-line matches: a substring would also be found in the notes text.
    [ "$(head -n 2 "${GH_ARGS_FILE}")" = $'release\ncreate' ]

    grep -qx -- '--title' "${GH_ARGS_FILE}"
    grep -qx -- '--notes' "${GH_ARGS_FILE}"
    grep -qx -- '--verify-tag' "${GH_ARGS_FILE}"
}

@test "honours an explicit VERSION over the latest" {

    VERSION=8.0.0 run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    args="$(cat "${GH_ARGS_FILE}")"
    grep -qx '8.0.0' "${GH_ARGS_FILE}"

    [[ "${args}" == *"An older change."* ]]
    [[ "${args}" != *"Exit-code retry helper."* ]]
}

@test "TAG overrides the tag but title stays the version" {

    TAG=v8.1.0 run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    grep -qx 'v8.1.0' "${GH_ARGS_FILE}"   # tag
    grep -qx '8.1.0'  "${GH_ARGS_FILE}"   # title
}

@test "adds --draft when DRAFT=true" {

    DRAFT=true run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(cat "${GH_ARGS_FILE}")" == *"--draft"* ]]
}

@test "adds --prerelease when PRERELEASE=true" {

    PRERELEASE=true run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(cat "${GH_ARGS_FILE}")" == *"--prerelease"* ]]
}

@test "attaches a single asset path when FILES is set" {

    touch "${BATS_TEST_TMPDIR}/mod-1.0.0.zip"
    FILES="${BATS_TEST_TMPDIR}/mod-1.0.0.zip" run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    grep -qx "${BATS_TEST_TMPDIR}/mod-1.0.0.zip" "${GH_ARGS_FILE}"
}

@test "attaches every non-blank line of a multi-asset FILES" {

    touch "${BATS_TEST_TMPDIR}/a.zip" "${BATS_TEST_TMPDIR}/b.zip"
    FILES="$(printf '%s\n\n%s\n' "${BATS_TEST_TMPDIR}/a.zip" "${BATS_TEST_TMPDIR}/b.zip")" run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    grep -qx "${BATS_TEST_TMPDIR}/a.zip" "${GH_ARGS_FILE}"
    grep -qx "${BATS_TEST_TMPDIR}/b.zip" "${GH_ARGS_FILE}"
}

@test "attaches no asset args when FILES is empty" {

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    # No asset path means no '.zip' positional reaches gh.
    [[ "$(cat "${GH_ARGS_FILE}")" != *".zip"* ]]
}

@test "appends NOTES_SUFFIX below the changelog section" {

    NOTES_SUFFIX="Built against [Upstream 1.0.0](https://example.invalid/r/1.0.0)." \
        run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    args="$(cat "${GH_ARGS_FILE}")"

    [[ "${args}" == *"Exit-code retry helper."* ]]
    [[ "${args}" == *"Built against [Upstream 1.0.0]"* ]]
}

@test "separates the suffix from the body with a blank line before the rule" {

    NOTES_SUFFIX="Trailer." run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    # A rule directly under text is Markdown's setext heading form, which
    # would render the changelog's last line as an H2 in the published
    # release rather than drawing a rule under it.
    [[ "$(cat "${GH_ARGS_FILE}")" == *$'\n\n---\n\nTrailer.'* ]]
}

@test "puts the suffix after the changelog body, not before it" {

    NOTES_SUFFIX="Trailer." run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    notes="$(cat "${GH_ARGS_FILE}")"

    [[ "${notes%%Trailer.*}" == *"Exit-code retry helper."* ]]
}

@test "leaves the body untouched when no suffix is given" {

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    # Every caller predating this input takes this path, so the body must
    # carry no rule and no trailing separator.
    [[ "$(cat "${GH_ARGS_FILE}")" != *"---"* ]]
}

@test "treats a whitespace-only suffix as absent" {

    # What an unset workflow expression interpolates to. Appending it would
    # publish a rule with nothing under it.

    NOTES_SUFFIX="$(printf '  \n\t\n')" run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(cat "${GH_ARGS_FILE}")" != *"---"* ]]
}

@test "trims whitespace around the suffix" {

    # A workflow expression carries a leading or trailing newline as a matter
    # of course (folded scalars, format()). Appended untrimmed it renders as
    # extra blank lines between the rule and the text.
    NOTES_SUFFIX="$(printf '\n\n  Trailer.  \n\n')" run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(cat "${GH_ARGS_FILE}")" == *$'\n\n---\n\nTrailer.'* ]]
}

@test "keeps blank lines inside a suffix, trimming only its ends" {

    # Internal spacing is the caller's markdown - two paragraphs must stay
    # two paragraphs.
    NOTES_SUFFIX="$(printf '\nFirst.\n\nSecond.\n')" run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(cat "${GH_ARGS_FILE}")" == *$'\n\n---\n\nFirst.\n\nSecond.'* ]]
}

@test "carries a multi-line suffix through verbatim" {

    NOTES_SUFFIX="$(printf 'First line.\nSecond line.')" run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "$(cat "${GH_ARGS_FILE}")" == *$'First line.\nSecond line.'* ]]
}

@test "still fails on a missing section even with a suffix set" {

    # The suffix must not become a way to publish a release with no notes.
    VERSION=9.9.9 NOTES_SUFFIX="Trailer." run "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [ ! -f "${GH_ARGS_FILE}" ]
}

@test "fails without calling gh when the version has no section" {

    VERSION=9.9.9 run "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"no changelog entry for version '9.9.9'"* ]]
    [ ! -f "${GH_ARGS_FILE}" ]
}

@test "fails when the changelog has no version heading at all" {

    printf '# Changelog\n\n## [Unreleased]\n' > "${CHANGELOG}"
    run "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"no '## [X.Y.Z]' version heading"* ]]
    [ ! -f "${GH_ARGS_FILE}" ]
}

@test "fails when the changelog file is missing" {

    rm -f "${CHANGELOG}"
    run "${SCRIPT}"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"changelog not found"* ]]
}
