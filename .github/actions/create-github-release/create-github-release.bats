#!/usr/bin/env bats
# Unit tests for create-github-release.sh.
# Run with: bats actions/create-github-release/create-github-release.bats

SCRIPT="${BATS_TEST_DIRNAME}/create-github-release.sh"

setup() {
    TMP="$(mktemp -d)"

    # gh stub on PATH: record every argument (one per line, so a multi-line
    # --notes value lands verbatim) and succeed.
    mkdir -p "${TMP}/bin"
    cat > "${TMP}/bin/gh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "${TMP}/gh.args"
exit 0
STUB
    chmod +x "${TMP}/bin/gh"
    export PATH="${TMP}/bin:${PATH}"

    export CHANGELOG="${TMP}/CHANGELOG.md"
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

teardown() {
    rm -rf "${TMP}"
}

@test "auto-detects the latest version, skipping Unreleased" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    # Tag and title are both the detected version.
    grep -qx '8.1.0' "${TMP}/gh.args"
    [[ "$(cat "${TMP}/gh.args")" != *"Unreleased"* ]]
}

@test "passes the changelog section as the notes body" {
    # Section parsing itself is covered by .github/lib/changelog.bats; here
    # we only confirm the action threads that body through to gh.
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMP}/gh.args")" == *"Exit-code retry helper."* ]]
}

@test "passes the expected gh subcommand and flags" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    args="$(cat "${TMP}/gh.args")"
    [[ "${args}" == *"release"* ]]
    [[ "${args}" == *"create"* ]]
    [[ "${args}" == *"--title"* ]]
    [[ "${args}" == *"--notes"* ]]
    [[ "${args}" == *"--verify-tag"* ]]
}

@test "honours an explicit VERSION over the latest" {
    VERSION=8.0.0 run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    args="$(cat "${TMP}/gh.args")"
    grep -qx '8.0.0' "${TMP}/gh.args"
    [[ "${args}" == *"An older change."* ]]
    [[ "${args}" != *"Exit-code retry helper."* ]]
}

@test "TAG overrides the tag but title stays the version" {
    TAG=v8.1.0 run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qx 'v8.1.0' "${TMP}/gh.args"   # tag
    grep -qx '8.1.0'  "${TMP}/gh.args"   # title
}

@test "adds --draft when DRAFT=true" {
    DRAFT=true run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMP}/gh.args")" == *"--draft"* ]]
}

@test "adds --prerelease when PRERELEASE=true" {
    PRERELEASE=true run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMP}/gh.args")" == *"--prerelease"* ]]
}

@test "attaches a single asset path when FILES is set" {
    touch "${TMP}/mod-1.0.0.zip"
    FILES="${TMP}/mod-1.0.0.zip" run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qx "${TMP}/mod-1.0.0.zip" "${TMP}/gh.args"
}

@test "attaches every non-blank line of a multi-asset FILES" {
    touch "${TMP}/a.zip" "${TMP}/b.zip"
    FILES="$(printf '%s\n\n%s\n' "${TMP}/a.zip" "${TMP}/b.zip")" run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qx "${TMP}/a.zip" "${TMP}/gh.args"
    grep -qx "${TMP}/b.zip" "${TMP}/gh.args"
}

@test "attaches no asset args when FILES is empty" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    # No asset path means no '.zip' positional reaches gh.
    [[ "$(cat "${TMP}/gh.args")" != *".zip"* ]]
}

@test "appends NOTES_SUFFIX below the changelog section" {
    NOTES_SUFFIX="Built against [Upstream 1.0.0](https://example.invalid/r/1.0.0)." \
        run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    args="$(cat "${TMP}/gh.args")"
    [[ "${args}" == *"Exit-code retry helper."* ]]
    [[ "${args}" == *"Built against [Upstream 1.0.0]"* ]]
}

@test "separates the suffix from the body with a blank line before the rule" {
    NOTES_SUFFIX="Trailer." run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    # A rule directly under text is Markdown's setext heading form, which
    # would render the changelog's last line as an H2 in the published
    # release rather than drawing a rule under it.
    [[ "$(cat "${TMP}/gh.args")" == *$'\n\n---\n\nTrailer.'* ]]
}

@test "puts the suffix after the changelog body, not before it" {
    NOTES_SUFFIX="Trailer." run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    notes="$(cat "${TMP}/gh.args")"
    [[ "${notes%%Trailer.*}" == *"Exit-code retry helper."* ]]
}

@test "leaves the body untouched when no suffix is given" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    # Every caller predating this input takes this path, so the body must
    # carry no rule and no trailing separator.
    [[ "$(cat "${TMP}/gh.args")" != *"---"* ]]
}

@test "treats a whitespace-only suffix as absent" {
    # What an unset workflow expression interpolates to. Appending it would
    # publish a rule with nothing under it.
    NOTES_SUFFIX="$(printf '  \n\t\n')" run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMP}/gh.args")" != *"---"* ]]
}

@test "carries a multi-line suffix through verbatim" {
    NOTES_SUFFIX="$(printf 'First line.\nSecond line.')" run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "$(cat "${TMP}/gh.args")" == *$'First line.\nSecond line.'* ]]
}

@test "still fails on a missing section even with a suffix set" {
    # The suffix must not become a way to publish a release with no notes.
    VERSION=9.9.9 NOTES_SUFFIX="Trailer." run "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [ ! -f "${TMP}/gh.args" ]
}

@test "fails without calling gh when the version has no section" {
    VERSION=9.9.9 run "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"no changelog entry for version '9.9.9'"* ]]
    [ ! -f "${TMP}/gh.args" ]
}

@test "fails when the changelog has no version heading at all" {
    printf '# Changelog\n\n## [Unreleased]\n' > "${CHANGELOG}"
    run "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"no '## [X.Y.Z]' version heading"* ]]
    [ ! -f "${TMP}/gh.args" ]
}

@test "fails when the changelog file is missing" {
    rm -f "${CHANGELOG}"
    run "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"changelog not found"* ]]
}
