#!/usr/bin/env bats
# Unit tests for add-merge-source.sh.
# Run with: bats .github/actions/publish-download-badges/chain/add-merge-source.bats
#
# write_run_page_table is replaced after the file is sourced, recording what
# it was handed; its own suite covers the dry run.

# shellcheck source=SCRIPTDIR/add-merge-source.sh
source "${BATS_TEST_DIRNAME}/add-merge-source.sh"

setup() {

    RECORD_DIR="${BATS_TEST_TMPDIR}/records"
    mkdir -p "${RECORD_DIR}"

    SOURCE_FILE="${BATS_TEST_TMPDIR}/nexus-summary.tsv"
    printf '1.2.3\ten\t7\n' > "${SOURCE_FILE}"

    MERGE_SOURCES=()
}

# Records its arguments and its stdin.
write_run_page_table() {

    printf '%s\n' "$@" > "${RECORD_DIR}/table.args"
    cat > "${RECORD_DIR}/table.stdin"
}

@test "shows the source's lines under its name, in the source summary's columns" {

    add_merge_source Nexus "${SOURCE_FILE}"

    [ "$(cat "${RECORD_DIR}/table.args")" = "Nexus
version
locale
downloads" ]
    [ "$(cat "${RECORD_DIR}/table.stdin")" = $'1.2.3\ten\t7' ]
}

@test "appends the source to the merge's arguments as a name and file pair" {

    MERGE_SOURCES=(Fossic ledger.json)

    add_merge_source Nexus "${SOURCE_FILE}"

    [ "${MERGE_SOURCES[*]}" = "Fossic ledger.json Nexus ${SOURCE_FILE}" ]
}
