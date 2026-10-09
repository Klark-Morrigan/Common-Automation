#!/usr/bin/env bats
# Unit tests for publish-download-badges.sh.
# Run with: bats .github/actions/publish-download-badges/publish-download-badges.bats
#
# The script finds its stages beside itself, so each case runs a copy of it in
# a folder of stage stubs. Each stub records how it was called. A stub stands
# in for every render-*.sh in this folder, so a renderer the script does not
# call fails the cases that expect every renderer.

# shellcheck source=./release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

SCRIPT_NAME="publish-download-badges.sh"
SUMMARY_STAGE="summarise-release-downloads.sh"
PUBLISH_STAGE="publish-badge-branch.sh"

LABEL="tool"
BRANCH="badges"

setup() {

    STUB_DIR="${BATS_TEST_TMPDIR}/action"
    mkdir -p "${STUB_DIR}"
    cp "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" "${STUB_DIR}/${SCRIPT_NAME}"

    export RECORD_DIR="${BATS_TEST_TMPDIR}/records"
    mkdir -p "${RECORD_DIR}"

    RENDERERS=()

    local renderer_path

    for renderer_path in "${BATS_TEST_DIRNAME}"/render-*.sh; do
        RENDERERS+=("${renderer_path##*/}")
    done

    SUMMARY="$(build_summary_line 1.2.3 2026-09-01T00:00:00Z 40)"
    export SUMMARY

    write_summary_stub
    write_publish_stub

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        write_renderer_stub "${renderer}"
    done

    export BADGE_LABEL="${LABEL}"
    export BADGE_BRANCH="${BRANCH}"

    # Stage failures a case may switch on.
    unset SUMMARY_STUB_EXIT RENDERER_STUB_EXIT
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
printf '%s\n' "${SUMMARY}"
exit "${SUMMARY_STUB_EXIT:-0}"
STUB
}

# Records its arguments and its stdin, then exits with RENDERER_STUB_EXIT.
#   write_renderer_stub <file name>
write_renderer_stub() {

    write_stage_stub "$1" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "\${RECORD_DIR}/$1.args"
cat > "\${RECORD_DIR}/$1.stdin"
exit "\${RENDERER_STUB_EXIT:-0}"
STUB
}

# Records its arguments and the files in the directory it was handed, which
# the script deletes once the run ends.
write_publish_stub() {

    write_stage_stub "${PUBLISH_STAGE}" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${RECORD_DIR}/publish.args"
find "$1" -mindepth 1 > "${RECORD_DIR}/publish.files"
STUB
}

publish_badges() {

    run "${STUB_DIR}/${SCRIPT_NAME}"
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

@test "every renderer writes into the directory that is published" {

    publish_badges

    [ "${status}" -eq 0 ]

    local renderer

    for renderer in "${RENDERERS[@]}"; do
        grep -qxF "$(read_published_dir)" "${RECORD_DIR}/${renderer}.args"
    done
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

@test "a failed renderer publishes nothing" {

    export RENDERER_STUB_EXIT=1
    publish_badges

    [ "${status}" -ne 0 ]
    [ ! -e "${RECORD_DIR}/publish.args" ]
}

@test "requires the label, before asking for the summary" {

    unset BADGE_LABEL
    publish_badges

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"BADGE_LABEL is required"* ]]
    [ ! -e "${RECORD_DIR}/summary.calls" ]
}

@test "requires the branch, before asking for the summary" {

    unset BADGE_BRANCH
    publish_badges

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"BADGE_BRANCH is required"* ]]
    [ ! -e "${RECORD_DIR}/summary.calls" ]
}
