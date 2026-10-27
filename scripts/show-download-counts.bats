#!/usr/bin/env bats
# Unit tests for show-download-counts.sh.
# Run with: bats scripts/show-download-counts.bats
#
# The script finds the chain through its own location, so each case runs a
# copy of it in a stand-in repository tree. There the chain is a stub that
# prints every variable the action's inputs map to, so a case sees what the
# flags became, and describe_git_checkout is a stub naming the directory it
# was handed. The tree holds the real input map and the real helpers the
# script sources besides.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

REPOSITORY="Klark-Morrigan/Starsector-Mod-KMU"
ASSET_NAME_REGEX_VALUE='^KMU-[0-9]+\.[0-9]+\.[0-9]+(-(?<locale>.+))?\.zip$'
DEFAULT_LOCALE_VALUE="en"
LABEL="KMU"

# The inputs a dry run takes no flag for.
DRY_RUN_UNUSED_INPUTS=(branch token)

setup() {

    local stand_in_root="${BATS_TEST_TMPDIR}/repo"
    local action_dir="${stand_in_root}/.github/actions/publish-download-badges"
    local lib_dir="${stand_in_root}/.github/lib"

    STAND_IN_SCRIPTS_DIR="${stand_in_root}/scripts"
    STAND_IN_ROOT="${stand_in_root}"

    mkdir -p "${STAND_IN_SCRIPTS_DIR}" "${lib_dir}" "${action_dir}"

    cp "${BATS_TEST_DIRNAME}/show-download-counts.sh" \
        "${BATS_TEST_DIRNAME}/_hold-window.sh" \
        "${BATS_TEST_DIRNAME}/log.sh" \
        "${STAND_IN_SCRIPTS_DIR}/"
    cp "${BATS_TEST_DIRNAME}/../.github/lib/colors.sh" \
        "${BATS_TEST_DIRNAME}/../.github/lib/print-section-heading.sh" \
        "${lib_dir}/"
    cp "${BATS_TEST_DIRNAME}/../.github/actions/publish-download-badges/action-input-variables.sh" "${action_dir}/"

    cat > "${lib_dir}/describe-git-checkout.sh" <<'STUB'
describe_git_checkout() {
    printf 'checkout of %s\n' "$1"
}
STUB

    cat > "${action_dir}/publish-download-badges.sh" <<'STUB'
#!/usr/bin/env bash
source "${0%/*}/action-input-variables.sh"
for variable in GITHUB_REPOSITORY "${ACTION_INPUT_VARIABLES[@]#*=}" BADGE_DRY_RUN; do
    printf '%s=%s\n' "${variable}" "${!variable-<unset>}"
done
STUB
    chmod +x "${action_dir}/publish-download-badges.sh"

    # shellcheck source=SCRIPTDIR/../.github/actions/publish-download-badges/action-input-variables.sh
    source "${action_dir}/action-input-variables.sh"

    unset "${ACTION_INPUT_VARIABLES[@]#*=}" GITHUB_REPOSITORY BADGE_DRY_RUN
}

show_download_counts() {

    run --separate-stderr "${STAND_IN_SCRIPTS_DIR}/show-download-counts.sh" "$@"
}

# Runs the script with every required flag, plus the given ones.
show_download_counts_with_required_flags() {

    show_download_counts \
        --repository "${REPOSITORY}" \
        --asset-name-regex "${ASSET_NAME_REGEX_VALUE}" \
        --label "${LABEL}" \
        "$@"
}

@test "hands each flag to the chain as its variable, as a dry run" {

    show_download_counts_with_required_flags --default-locale "${DEFAULT_LOCALE_VALUE}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "GITHUB_REPOSITORY=${REPOSITORY}
ASSET_NAME_REGEX=${ASSET_NAME_REGEX_VALUE}
BADGE_BRANCH=<unset>
DEFAULT_LOCALE=${DEFAULT_LOCALE_VALUE}
BADGE_LABEL=${LABEL}
NEXUS_FILE_NAME=<unset>
NEXUS_GAME_ID=<unset>
NEXUS_LOCALE=<unset>
NEXUS_MOD_ID=<unset>
GH_TOKEN=<unset>
BADGE_DRY_RUN=true" ]
}

@test "hands the Nexus flags to the chain as their variables" {

    show_download_counts_with_required_flags \
        --nexus-mod-id 160 \
        --nexus-game-id 2672 \
        --nexus-file-name "${LABEL}" \
        --nexus-locale "${DEFAULT_LOCALE_VALUE}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"
NEXUS_FILE_NAME=${LABEL}
NEXUS_GAME_ID=2672
NEXUS_LOCALE=${DEFAULT_LOCALE_VALUE}
NEXUS_MOD_ID=160
"* ]]
}

# A new input reaches the dry run through the shared map alone, so this case
# walks the map rather than naming the inputs.
@test "takes a flag for every action input a dry run uses" {

    local input_variable input

    for input_variable in "${ACTION_INPUT_VARIABLES[@]}"; do

        input="${input_variable%%=*}"

        if [[ " ${DRY_RUN_UNUSED_INPUTS[*]} " == *" ${input} "* ]]; then
            continue
        fi

        show_download_counts_with_required_flags "--${input}" "value of ${input}"

        [ "${status}" -eq 0 ]
        [[ "${output}" == *$'\n'"${input_variable#*=}=value of ${input}"$'\n'* ]]
    done
}

@test "takes no flag for an input a dry run has no use for" {

    local input

    for input in "${DRY_RUN_UNUSED_INPUTS[@]}"; do

        show_download_counts_with_required_flags "--${input}" "value"

        [ "${status}" -eq 2 ]
        [[ "${stderr}" == *"unknown flag '--${input}'."* ]]
    done
}

# A mod without a manifest has an empty default locale, which the chain reads
# as "no locales".
@test "keeps an empty default locale" {

    show_download_counts_with_required_flags --default-locale ""

    [ "${status}" -eq 0 ]
    [[ "${output}" == *$'\nDEFAULT_LOCALE=\n'* ]]
}

@test "ignores a variable left in the shell for a flag not given" {

    export DEFAULT_LOCALE="zh-hans"
    show_download_counts_with_required_flags

    [ "${status}" -eq 0 ]
    [[ "${output}" == *$'\nDEFAULT_LOCALE=<unset>\n'* ]]
}

@test "an unknown flag fails, naming it, before the chain runs" {

    show_download_counts_with_required_flags --bogus value

    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"unknown flag '--bogus'."* ]]
    [ -z "${output}" ]
}

@test "a flag with no value fails, naming it" {

    show_download_counts --label

    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"flag '--label' needs a value."* ]]
    [ -z "${output}" ]
}

@test "a missing required flag fails, naming the flag, before the chain runs" {

    show_download_counts --repository "${REPOSITORY}" --label "${LABEL}"

    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"flag '--asset-name-regex' is required."* ]]
    [ -z "${output}" ]
}

@test "logs its own checkout under a heading before the chain runs" {

    show_download_counts_with_required_flags

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "=== Common-Automation checkout ===
checkout of ${STAND_IN_ROOT}" ]
}
