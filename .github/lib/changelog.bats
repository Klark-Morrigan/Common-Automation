#!/usr/bin/env bats
# Unit tests for .github/lib/changelog.sh.
# Run with: bats .github/lib/changelog.bats

setup() {
    # shellcheck source=./changelog.sh
    source "${BATS_TEST_DIRNAME}/changelog.sh"

    TMP="$(mktemp -d)"
    CL="${TMP}/CHANGELOG.md"
    cat > "${CL}" <<'MD'
# Changelog

## [Unreleased]

## [8.1.0] - 2026-06-14

### Added
- Thing A.
- Thing B.

## [8.0.0] - 2026-06-13

### Changed
- An older change.
MD
}

teardown() {
    rm -rf "${TMP}"
}

@test "changelog_latest_version returns the top versioned heading, skipping Unreleased" {
    run changelog_latest_version "${CL}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "8.1.0" ]
}

@test "changelog_latest_version is empty when there is no version heading" {
    printf '# Changelog\n\n## [Unreleased]\n' > "${CL}"
    run changelog_latest_version "${CL}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "changelog_section returns only that version's body, trimmed" {
    run changelog_section "${CL}" "8.1.0"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Thing A."* ]]
    [[ "${output}" == *"Thing B."* ]]
    [[ "${output}" != *"An older change."* ]]
    [[ "${output}" != *"Unreleased"* ]]
    # Leading blank lines trimmed: the body starts at the first real line.
    [ "$(printf '%s' "${output}" | head -1)" = "### Added" ]
}

@test "changelog_section isolates an older version's section" {
    run changelog_section "${CL}" "8.0.0"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"An older change."* ]]
    [[ "${output}" != *"Thing A."* ]]
}

@test "changelog_section is empty for an absent version" {
    run changelog_section "${CL}" "9.9.9"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
