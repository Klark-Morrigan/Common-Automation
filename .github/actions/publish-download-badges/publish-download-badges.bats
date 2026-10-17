#!/usr/bin/env bats
# Unit tests for publish-download-badges.sh.
# Run with: bats .github/actions/publish-download-badges/publish-download-badges.bats
#
# The script finds its stages beside itself, so each case runs a copy of it in
# a folder of stage stubs. Each stub records how it was called and logs one
# line to stderr, as a stage does. A stub stands in for every render-*.sh in
# this folder, so a renderer the script does not call fails the cases that
# expect every renderer. The table and renderer stubs also note when they ran,
# for the cases on stage order.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=./release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

SCRIPT_NAME="publish-download-badges.sh"
SUMMARY_STAGE="summarise-release-downloads.sh"
TABLE_STAGE="write-step-summary-table.sh"
PUBLISH_STAGE="publish-badge-branch.sh"

LABEL="tool"
BRANCH="badges"

setup() {

    STUB_DIR="${BATS_TEST_TMPDIR}/action"
    mkdir -p "${STUB_DIR}"
    cp "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" "${STUB_DIR}/${SCRIPT_NAME}"

    # The copy sits away from .github/lib, so it is pointed back at this repo
    # as the composite points the real script.
    COMMON_AUTOMATION_REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
    export COMMON_AUTOMATION_REPO_ROOT

    export RECORD_DIR="${BATS_TEST_TMPDIR}/records"
    mkdir -p "${RECORD_DIR}"

    RENDERERS=()

    local renderer_path

    for renderer_path in "${BATS_TEST_DIRNAME}"/render-*.sh; do
        RENDERERS+=("${renderer_path##*/}")
    done

    SUMMARY="$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"
    export SUMMARY

    write_summary_stub
    write_table_stub
    write_publish_stub

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        write_renderer_stub "${renderer}"
    done

    export BADGE_LABEL="${LABEL}"
    export BADGE_BRANCH="${BRANCH}"

    # Stage failures a case may switch on.
    unset SUMMARY_STUB_EXIT TABLE_STUB_EXIT RENDERER_STUB_EXIT
}

# Writes an executable stub stage, its body read from stdin.
#   write_stage_stub <file name> <<STUB
write_stage_stub() {

    cat > "${STUB_DIR}/$1"
    chmod +x "${STUB_DIR}/$1"
}

# Counts its calls, prints the summary and exits with SUMMARY_STUB_EXIT.
write_summary_stub() {

    write_stage_stub "${SUMMARY_STAGE}" <<'STUB'
#!/usr/bin/env bash
echo call >> "${RECORD_DIR}/summary.calls"
echo "${0##*/} ran." >&2
printf '%s\n' "${SUMMARY}"
exit "${SUMMARY_STUB_EXIT:-0}"
STUB
}

# Records its arguments and its stdin, notes that it ran, then exits with
# TABLE_STUB_EXIT.
write_table_stub() {

    write_stage_stub "${TABLE_STAGE}" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${RECORD_DIR}/table.args"
cat > "${RECORD_DIR}/table.stdin"
echo "${0##*/}" >> "${RECORD_DIR}/stage.order"
echo "${0##*/} ran." >&2
exit "${TABLE_STUB_EXIT:-0}"
STUB
}

# Records its arguments and its stdin under its own file name, notes that it
# ran, then exits with RENDERER_STUB_EXIT.
#   write_renderer_stub <file name>
write_renderer_stub() {

    write_stage_stub "$1" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${RECORD_DIR}/${0##*/}.args"
cat > "${RECORD_DIR}/${0##*/}.stdin"
echo "${0##*/}" >> "${RECORD_DIR}/stage.order"
echo "${0##*/} ran." >&2
exit "${RENDERER_STUB_EXIT:-0}"
STUB
}

# Records its arguments and the files in the directory it was handed, which
# the script deletes once the run ends.
write_publish_stub() {

    write_stage_stub "${PUBLISH_STAGE}" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${RECORD_DIR}/publish.args"
find "$1" -mindepth 1 > "${RECORD_DIR}/publish.files"
echo "${0##*/} ran." >&2
STUB
}

# Prints the line every stub logs, given the stub's file name.
build_stub_log_line() {

    printf '%s ran.' "$1"
}

# Prints the given stage's log as the script should frame it: the stub's line
# inside a group named after the stage.
build_grouped_stage_log() {

    printf '::group::%s\n%s\n::endgroup::' "${1%.sh}" "$(build_stub_log_line "$1")"
}

publish_badges() {

    run --separate-stderr "${STUB_DIR}/${SCRIPT_NAME}"
}

# Prints the directory the publish stage was handed.
read_published_dir() {

    sed -n 1p "${RECORD_DIR}/publish.args"
}

@test "runs the summary once" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ "$(wc -l < "${RECORD_DIR}/summary.calls")" -eq 1 ]
}

@test "feeds the summary to every renderer" {

    publish_badges

    [ "${status}" -eq 0 ]

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        [ "$(cat "${RECORD_DIR}/${renderer}.stdin")" = "${SUMMARY}" ]
    done
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
    [ "$(cat "${RECORD_DIR}/table.stdin")" = "${SUMMARY}" ]
    [ "$(cat "${RECORD_DIR}/table.args")" = "Release downloads
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

@test "a failed summary renders and publishes nothing" {

    export SUMMARY_STUB_EXIT=1
    publish_badges

    [ "${status}" -ne 0 ]
    [ ! -e "${RECORD_DIR}/publish.args" ]

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        [ ! -e "${RECORD_DIR}/${renderer}.args" ]
    done
}

@test "a failed summary writes no table" {

    export SUMMARY_STUB_EXIT=1
    publish_badges

    [ "${status}" -ne 0 ]
    [ ! -e "${RECORD_DIR}/table.args" ]
}

@test "a failed table renders and publishes nothing" {

    export TABLE_STUB_EXIT=1
    publish_badges

    [ "${status}" -ne 0 ]
    [ ! -e "${RECORD_DIR}/publish.args" ]

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        [ ! -e "${RECORD_DIR}/${renderer}.args" ]
    done
}

@test "a failed renderer publishes nothing" {

    export RENDERER_STUB_EXIT=1
    publish_badges

    [ "${status}" -ne 0 ]
    [ ! -e "${RECORD_DIR}/publish.args" ]
}

@test "wraps each stage's log in a group named after the stage" {

    publish_badges

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"$(build_grouped_stage_log "${SUMMARY_STAGE}")"* ]]
    [[ "${stderr}" == *"$(build_grouped_stage_log "${TABLE_STAGE}")"* ]]
    [[ "${stderr}" == *"$(build_grouped_stage_log "${PUBLISH_STAGE}")"* ]]

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        [[ "${stderr}" == *"$(build_grouped_stage_log "${renderer}")"* ]]
    done
}

@test "logs nothing to stdout" {

    publish_badges

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "closes the group of a failed stage" {

    export SUMMARY_STUB_EXIT=1
    publish_badges

    [ "${status}" -ne 0 ]
    [ "${stderr}" = "$(build_grouped_stage_log "${SUMMARY_STAGE}")" ]
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
