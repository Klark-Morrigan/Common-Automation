#!/usr/bin/env bats
# Unit tests for write-run-page-table.sh.
# Run with: bats .github/actions/publish-download-badges/chain/write-run-page-table.bats
#
# run_stage is replaced after the file is sourced, recording what it was
# handed; its own suite covers it.

# shellcheck source=SCRIPTDIR/write-run-page-table.sh
source "${BATS_TEST_DIRNAME}/write-run-page-table.sh"

TABLE_SCRIPT_NAME="write-step-summary-table.sh"

setup() {

    RECORD_DIR="${BATS_TEST_TMPDIR}/records"
    mkdir -p "${RECORD_DIR}"

    unset BADGE_DRY_RUN
}

# Records the stage's file name, its arguments and its stdin.
run_stage() {

    printf '%s\n' "${1##*/}" "${@:2}" > "${RECORD_DIR}/run-stage.args"
    cat > "${RECORD_DIR}/run-stage.stdin"
}

@test "runs the table writer as a stage, with the heading, the columns and the lines" {

    write_run_page_table "Nexus" version locale downloads <<< $'1.2.3\ten\t7'

    [ "$(cat "${RECORD_DIR}/run-stage.args")" = "${TABLE_SCRIPT_NAME}
Nexus
version
locale
downloads" ]
    [ "$(cat "${RECORD_DIR}/run-stage.stdin")" = $'1.2.3\ten\t7' ]
}

@test "runs the table writer from the shared lib" {

    # The stub keeps only the file name, so this case checks the path itself.
    run_stage() {
        printf '%s\n' "$1" > "${RECORD_DIR}/run-stage.path"
    }

    write_run_page_table "Nexus" version < /dev/null

    [ "$(cat "${RECORD_DIR}/run-stage.path")" -ef "${BATS_TEST_DIRNAME}/../../../lib/${TABLE_SCRIPT_NAME}" ]
}

@test "a dry run writes no table" {

    export BADGE_DRY_RUN=true

    write_run_page_table "Nexus" version < /dev/null

    [ ! -e "${RECORD_DIR}/run-stage.args" ]
}
