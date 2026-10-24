#!/usr/bin/env bats
# Unit tests for publish-download-badges.sh.
# Run with: bats .github/actions/publish-download-badges/publish-download-badges.bats
#
# The script finds its stages beside itself and in .github/lib, so each case
# runs a copy of it in a stand-in repository tree of stage stubs. Each stub
# records how it was called and logs one line to stderr, as a stage does. A
# stub stands in for every renderers/render-*.sh, so a renderer the script
# does not call fails the cases that expect every renderer.
#
# run_stage and print_rendered_endpoints are stubs too, which record their
# calls; their own suites cover them. The tree holds the real
# workflow-commands.sh, print-section-heading.sh and release-summary.sh: the
# annotations, the heading and the summary format are what these cases read
# back. publish-download-badges.integration.bats runs the real collaborators.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

SCRIPT_NAME="publish-download-badges.sh"
SUMMARY_STAGE="summarise-release-downloads.sh"
TABLE_STAGE="write-step-summary-table.sh"
PUBLISH_STAGE="publish-badge-branch.sh"

LABEL="tool"
BRANCH="badges"

DRY_RUN_FIRST_LINE="Dry run: every stage reads and renders, but no table is written and nothing is published."
DRY_RUN_LAST_LINE="Dry run: nothing was published."
RENDERED_ENDPOINTS_HEADING="=== Rendered endpoint files ==="

setup() {

    local stand_in_root="${BATS_TEST_TMPDIR}/repo"

    ACTION_STUB_DIR="${stand_in_root}/.github/actions/publish-download-badges"
    SOURCES_STUB_DIR="${ACTION_STUB_DIR}/sources"
    RENDERERS_STUB_DIR="${ACTION_STUB_DIR}/renderers"
    LIB_STUB_DIR="${stand_in_root}/.github/lib"

    mkdir -p "${SOURCES_STUB_DIR}" "${RENDERERS_STUB_DIR}" "${LIB_STUB_DIR}"

    cp "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" "${BATS_TEST_DIRNAME}/release-summary.sh" "${ACTION_STUB_DIR}/"
    cp "${BATS_TEST_DIRNAME}/../../lib/workflow-commands.sh" \
        "${BATS_TEST_DIRNAME}/../../lib/print-section-heading.sh" \
        "${LIB_STUB_DIR}/"

    # Pointed at the stand-in tree as the composite points the real script at
    # this repository.
    export COMMON_AUTOMATION_REPO_ROOT="${stand_in_root}"

    export RECORD_DIR="${BATS_TEST_TMPDIR}/records"
    mkdir -p "${RECORD_DIR}"

    RENDERERS=()

    local renderer_path

    for renderer_path in "${BATS_TEST_DIRNAME}"/renderers/render-*.sh; do
        RENDERERS+=("${renderer_path##*/}")
    done

    SUMMARY="$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"
    export SUMMARY

    write_summary_stub
    write_recording_stub "${LIB_STUB_DIR}/${TABLE_STAGE}"
    write_publish_stub
    write_run_stage_stub
    write_print_rendered_endpoints_stub

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        write_recording_stub "${RENDERERS_STUB_DIR}/${renderer}"
    done

    export BADGE_LABEL="${LABEL}"
    export BADGE_BRANCH="${BRANCH}"

    unset BADGE_DRY_RUN

    # The file name of the stage a case makes fail, if any.
    unset FAILING_STAGE
}

# Writes an executable stub stage, its body read from stdin.
#   write_stage_stub <path> <<STUB
write_stage_stub() {

    cat > "$1"
    chmod +x "$1"
}

# Counts its calls and prints the summary.
write_summary_stub() {

    write_stage_stub "${SOURCES_STUB_DIR}/${SUMMARY_STAGE}" <<'STUB'
#!/usr/bin/env bash
echo call >> "${RECORD_DIR}/summary.calls"
echo "${0##*/} ran." >&2
printf '%s\n' "${SUMMARY}"
[[ "${FAILING_STAGE:-}" != "${0##*/}" ]]
STUB
}

# Records its arguments and its stdin under its own file name, and notes that
# it ran, for the cases on stage order.
#   write_recording_stub <path>
write_recording_stub() {

    write_stage_stub "$1" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${RECORD_DIR}/${0##*/}.args"
cat > "${RECORD_DIR}/${0##*/}.stdin"
echo "${0##*/}" >> "${RECORD_DIR}/stage.order"
echo "${0##*/} ran." >&2
[[ "${FAILING_STAGE:-}" != "${0##*/}" ]]
STUB
}

# Records its arguments and the files in the directory it was handed, which
# the script deletes once the run ends.
write_publish_stub() {

    write_stage_stub "${ACTION_STUB_DIR}/${PUBLISH_STAGE}" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${RECORD_DIR}/publish.args"
find "$1" -mindepth 1 > "${RECORD_DIR}/publish.files"
echo "${0##*/} ran." >&2
STUB
}

# Records each stage it is handed, then runs it.
write_run_stage_stub() {

    cat > "${LIB_STUB_DIR}/run-stage.sh" <<'STUB'
run_stage() {
    echo "${1##*/}" >> "${RECORD_DIR}/run-stage.calls"
    "$@"
}
STUB
}

# Prints the directory it was handed, in place of its files.
write_print_rendered_endpoints_stub() {

    cat > "${ACTION_STUB_DIR}/print-rendered-endpoints.sh" <<'STUB'
print_rendered_endpoints() {
    printf 'endpoints of %s\n' "$1"
}
STUB
}

publish_badges() {

    run --separate-stderr "${ACTION_STUB_DIR}/${SCRIPT_NAME}"
}

# Prints the directory the publish stage was handed.
read_published_dir() {

    sed -n 1p "${RECORD_DIR}/publish.args"
}

# Prints the directory the first renderer was handed last, as each is.
read_rendered_dir() {

    tail -n 1 "${RECORD_DIR}/${RENDERERS[0]}.args"
}

# Fails, naming the renderer, unless every renderer read the summary.
assert_summary_reached_every_renderer() {

    local renderer

    for renderer in "${RENDERERS[@]}"; do

        if [[ "$(cat "${RECORD_DIR}/${renderer}.stdin")" != "${SUMMARY}" ]]; then

            echo "${renderer} did not read the summary" >&2

            return 1
        fi
    done
}

@test "runs the summary once" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ "$(wc -l < "${RECORD_DIR}/summary.calls")" -eq 1 ]
}

@test "feeds the summary to every renderer" {

    publish_badges

    [ "${status}" -eq 0 ]

    assert_summary_reached_every_renderer
}

@test "hands every renderer the directory that is published" {

    publish_badges

    [ "${status}" -eq 0 ]

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        grep -qxF "$(read_published_dir)" "${RECORD_DIR}/${renderer}.args"
    done
}

@test "writes the summary to the run page's table" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ "$(cat "${RECORD_DIR}/${TABLE_STAGE}.stdin")" = "${SUMMARY}" ]
    [ "$(cat "${RECORD_DIR}/${TABLE_STAGE}.args")" = "Release downloads
release
published
locale
downloads" ]
}

@test "writes the table before any renderer runs" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ "$(sed -n 1p "${RECORD_DIR}/stage.order")" = "${TABLE_STAGE}" ]
}

@test "hands the total renderer the label and the published directory" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ "$(cat "${RECORD_DIR}/render-total-downloads.sh.args")" = "${LABEL}
$(read_published_dir)" ]
}

@test "publishes to the given branch" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ "$(sed -n 2p "${RECORD_DIR}/publish.args")" = "${BRANCH}" ]
}

@test "publishes only what the renderers write" {

    # The renderer stubs write nothing, so any file found was put there by the
    # script itself - its summary above all.
    publish_badges

    [ "${status}" -eq 0 ]
    [ ! -s "${RECORD_DIR}/publish.files" ]
}

@test "removes its working files" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ ! -e "$(read_published_dir)" ]
}

@test "runs every stage through run_stage, in order" {

    publish_badges

    [ "${status}" -eq 0 ]

    local expected_calls

    expected_calls="$(printf '%s\n' "${SUMMARY_STAGE}" "${TABLE_STAGE}" "${RENDERERS[@]}" "${PUBLISH_STAGE}")"

    [ "$(cat "${RECORD_DIR}/run-stage.calls")" = "${expected_calls}" ]
}

@test "a failed summary writes no table, renders and publishes nothing" {

    export FAILING_STAGE="${SUMMARY_STAGE}"
    publish_badges

    [ "${status}" -ne 0 ]
    [ ! -e "${RECORD_DIR}/stage.order" ]
    [ ! -e "${RECORD_DIR}/publish.args" ]
}

@test "a failed table renders and publishes nothing" {

    export FAILING_STAGE="${TABLE_STAGE}"
    publish_badges

    [ "${status}" -ne 0 ]
    [ "$(cat "${RECORD_DIR}/stage.order")" = "${TABLE_STAGE}" ]
    [ ! -e "${RECORD_DIR}/publish.args" ]
}

@test "a failed renderer publishes nothing" {

    export FAILING_STAGE="${RENDERERS[0]}"
    publish_badges

    [ "${status}" -ne 0 ]
    [ ! -e "${RECORD_DIR}/publish.args" ]
}

@test "logs nothing to stdout" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "requires the label, before asking for the summary" {

    unset BADGE_LABEL
    publish_badges

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"BADGE_LABEL is required"* ]]
    [ ! -e "${RECORD_DIR}/summary.calls" ]
}

@test "requires the branch, before asking for the summary" {

    unset BADGE_BRANCH
    publish_badges

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"BADGE_BRANCH is required"* ]]
    [ ! -e "${RECORD_DIR}/summary.calls" ]
}

@test "a dry run writes no table and never publishes" {

    export BADGE_DRY_RUN=true
    publish_badges

    [ "${status}" -eq 0 ]
    [ ! -e "${RECORD_DIR}/${TABLE_STAGE}.args" ]
    [ ! -e "${RECORD_DIR}/publish.args" ]
}

@test "a dry run still feeds the summary to every renderer" {

    export BADGE_DRY_RUN=true
    publish_badges

    [ "${status}" -eq 0 ]

    assert_summary_reached_every_renderer
}

@test "a dry run prints the endpoint files the renderers wrote, under a heading" {

    export BADGE_DRY_RUN=true
    publish_badges

    [ "${status}" -eq 0 ]
    [ "${output}" = "endpoints of $(read_rendered_dir)" ]
    [ "${stderr_lines[-2]}" = "${RENDERED_ENDPOINTS_HEADING}" ]
}

@test "a dry run says so in its first and last line" {

    export BADGE_DRY_RUN=true
    publish_badges

    [ "${status}" -eq 0 ]
    [ "${stderr_lines[0]}" = "${DRY_RUN_FIRST_LINE}" ]
    [ "${stderr_lines[-1]}" = "${DRY_RUN_LAST_LINE}" ]
}

# A failed dry run must not end on a line that could be read as a publish.
@test "a failed dry run still ends on its last line" {

    export BADGE_DRY_RUN=true
    export FAILING_STAGE="${SUMMARY_STAGE}"
    publish_badges

    [ "${status}" -ne 0 ]
    [ "${stderr_lines[-1]}" = "${DRY_RUN_LAST_LINE}" ]
}

@test "a dry run needs no branch" {

    unset BADGE_BRANCH
    export BADGE_DRY_RUN=true
    publish_badges

    [ "${status}" -eq 0 ]
}
