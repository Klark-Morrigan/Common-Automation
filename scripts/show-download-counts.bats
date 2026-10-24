#!/usr/bin/env bats
# Unit tests for show-download-counts.sh.
# Run with: bats scripts/show-download-counts.bats
#
# The script finds the chain through its own location, so each case runs a
# copy of it in a stand-in repository tree. There the chain is a stub that
# prints the variables it was handed, so a case sees what the flags became.
# The tree holds the real helpers the script sources.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

REPOSITORY="Klark-Morrigan/Starsector-Mod-KMU"
ASSET_NAME_REGEX='^KMU-[0-9]+\.[0-9]+\.[0-9]+(-(?<locale>.+))?\.zip$'
DEFAULT_LOCALE="en"
LABEL="KMU"

setup() {

    local stand_in_root="${BATS_TEST_TMPDIR}/repo"
    local action_stub_dir="${stand_in_root}/.github/actions/publish-download-badges"

    STAND_IN_SCRIPTS_DIR="${stand_in_root}/scripts"

    mkdir -p "${STAND_IN_SCRIPTS_DIR}" "${stand_in_root}/.github/lib" "${action_stub_dir}"

    cp "${BATS_TEST_DIRNAME}/show-download-counts.sh" \
        "${BATS_TEST_DIRNAME}/_hold-window.sh" \
        "${BATS_TEST_DIRNAME}/log.sh" \
        "${STAND_IN_SCRIPTS_DIR}/"
    cp "${BATS_TEST_DIRNAME}/../.github/lib/colors.sh" "${stand_in_root}/.github/lib/"

    cat > "${action_stub_dir}/publish-download-badges.sh" <<'STUB'
#!/usr/bin/env bash
printf 'GITHUB_REPOSITORY=%s\n' "${GITHUB_REPOSITORY-<unset>}"
printf 'ASSET_NAME_REGEX=%s\n' "${ASSET_NAME_REGEX-<unset>}"
printf 'DEFAULT_LOCALE=%s\n' "${DEFAULT_LOCALE-<unset>}"
printf 'BADGE_LABEL=%s\n' "${BADGE_LABEL-<unset>}"
printf 'BADGE_DRY_RUN=%s\n' "${BADGE_DRY_RUN-<unset>}"
STUB
    chmod +x "${action_stub_dir}/publish-download-badges.sh"

    unset GITHUB_REPOSITORY ASSET_NAME_REGEX DEFAULT_LOCALE BADGE_LABEL BADGE_DRY_RUN
}

show_download_counts() {

    run --separate-stderr "${STAND_IN_SCRIPTS_DIR}/show-download-counts.sh" "$@"
}

@test "hands each flag to the chain as its variable, as a dry run" {

    show_download_counts \
        --repository "${REPOSITORY}" \
        --asset-name-regex "${ASSET_NAME_REGEX}" \
        --default-locale "${DEFAULT_LOCALE}" \
        --label "${LABEL}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "GITHUB_REPOSITORY=${REPOSITORY}
ASSET_NAME_REGEX=${ASSET_NAME_REGEX}
DEFAULT_LOCALE=${DEFAULT_LOCALE}
BADGE_LABEL=${LABEL}
BADGE_DRY_RUN=true" ]
}

# A mod without a manifest has an empty default locale, which the chain reads
# as "no locales".
@test "keeps an empty default locale" {

    show_download_counts --default-locale "" --label "${LABEL}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *$'\nDEFAULT_LOCALE=\n'* ]]
}

@test "an unknown flag fails, naming it, before the chain runs" {

    show_download_counts --label "${LABEL}" --branch badges

    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"unknown flag '--branch'."* ]]
    [ -z "${output}" ]
}

@test "a flag with no value fails, naming it" {

    show_download_counts --label

    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"flag '--label' needs a value."* ]]
    [ -z "${output}" ]
}
