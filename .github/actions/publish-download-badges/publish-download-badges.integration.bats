#!/usr/bin/env bats
# Integration tests for publish-download-badges.sh with its real
# collaborators: run_stage, both presenters, workflow-commands.sh and
# print_rendered_endpoints.
# Run with: bats .github/actions/publish-download-badges/publish-download-badges.integration.bats
#
# Each case runs a copy of the script in a stand-in repository tree that holds
# the real .github/lib. Only the stages are stubs: the summary writes one log
# record and the summary line, and each renderer writes an endpoint file
# named after itself.
#
# These cases hold the dry run as a person runs it from a terminal, outside
# Actions, except the one that sets GITHUB_ACTIONS.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

setup() {

    local stand_in_root="${BATS_TEST_TMPDIR}/repo"

    ACTION_STAND_IN_DIR="${stand_in_root}/.github/actions/publish-download-badges"

    mkdir -p "${ACTION_STAND_IN_DIR}/sources" "${ACTION_STAND_IN_DIR}/renderers"

    cp -r "${BATS_TEST_DIRNAME}/../../lib" "${stand_in_root}/.github/"
    cp "${BATS_TEST_DIRNAME}/publish-download-badges.sh" \
        "${BATS_TEST_DIRNAME}/release-summary.sh" \
        "${BATS_TEST_DIRNAME}/print-rendered-endpoints.sh" \
        "${ACTION_STAND_IN_DIR}/"

    export COMMON_AUTOMATION_REPO_ROOT="${stand_in_root}"

    SUMMARY="$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"
    export SUMMARY

    # The record's locale value comes out upper-cased only through the
    # presenter, so the case can tell a presented log from a raw one. The
    # notice goes through the real workflow-commands.sh, as a stage's does.
    write_stage_stub "${ACTION_STAND_IN_DIR}/sources/summarise-release-downloads.sh" <<'STUB'
#!/usr/bin/env bash
source "${COMMON_AUTOMATION_REPO_ROOT}/.github/lib/workflow-commands.sh"
printf '#log\tmessage\t\tCounting under \tlocale\ten\n' >&2
log_notice "counted."
printf '%s\n' "${SUMMARY}"
STUB

    local renderer_path

    RENDERERS=()

    for renderer_path in "${BATS_TEST_DIRNAME}"/renderers/render-*.sh; do

        RENDERERS+=("${renderer_path##*/}")
        write_stage_stub "${ACTION_STAND_IN_DIR}/renderers/${renderer_path##*/}" <<'STUB'
#!/usr/bin/env bash
cat > /dev/null
printf '{"figure":"%s"}\n' "${0##*/}" > "${@: -1}/${0##*/}.json"
STUB
    done

    export BADGE_LABEL="tool"
    export BADGE_DRY_RUN=true

    unset GITHUB_ACTIONS BADGE_BRANCH
}

# Writes an executable stub stage, its body read from stdin.
#   write_stage_stub <path> <<STUB
write_stage_stub() {

    cat > "$1"
    chmod +x "$1"
}

publish_badges() {

    run --separate-stderr "${ACTION_STAND_IN_DIR}/publish-download-badges.sh"
}

@test "a dry run shapes each stage's log for the terminal" {

    publish_badges

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Counting under EN"* ]]
    [[ "${stderr}" == *$'\nsummarise-release-downloads: counted.\n'* ]]
    [[ "${stderr}" != *"#log"* ]]
}

# A dry run under Actions is how a dispatched run's log is checked without a
# publish.
@test "under Actions, each stage's log is shaped for Actions, its notice an annotation" {

    export GITHUB_ACTIONS=true
    publish_badges

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"::group::summarise-release-downloads"* ]]
    [[ "${stderr}" == *"Counting under EN"* ]]
    [[ "${stderr}" == *"::notice::summarise-release-downloads: counted."* ]]
    [[ "${stderr}" != *"#log"* ]]
}

@test "a dry run heads each stage's log with its name, with no group markers" {

    publish_badges

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"=== summarise-release-downloads ==="* ]]

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        [[ "${stderr}" == *"=== ${renderer%.sh} ==="* ]]
    done

    [[ "${stderr}" != *"::group::"* ]]
}

# The figures are the dry run's result, so they stay on stdout, unshaped.
@test "a dry run prints each rendered endpoint file on stdout, untouched by the presenter" {

    publish_badges

    [ "${status}" -eq 0 ]

    local expected_output=""
    local renderer

    for renderer in "${RENDERERS[@]}"; do
        expected_output+="${renderer}.json: {\"figure\":\"${renderer}\"}"$'\n'
    done

    [ "${output}" = "${expected_output%$'\n'}" ]
}
