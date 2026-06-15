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
    unset VERSION TAG DRAFT PRERELEASE
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

@test "release body is only the matched version's section" {
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    args="$(cat "${TMP}/gh.args")"
    [[ "${args}" == *"Exit-code retry helper."* ]]
    [[ "${args}" == *"A second bullet."* ]]
    # The older section must not bleed in.
    [[ "${args}" != *"An older change."* ]]
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
