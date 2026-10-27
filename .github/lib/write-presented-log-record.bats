#!/usr/bin/env bats
# Unit tests for write-presented-log-record.sh.
# Run with: bats .github/lib/write-presented-log-record.bats
#
# The function finds its collaborators beside its own file, so each case
# sources a copy of it from a stand-in lib tree. There resolve_log_presenter is
# a stub that picks a stand-in presenter path, and run_stage_through_presenter
# a stub that records what it was handed, then returns STAGE_EXIT.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

STAND_IN_PRESENTER="present-log-for-example.sh"

setup() {

    local stand_in_lib="${BATS_TEST_TMPDIR}/lib"

    mkdir -p "${stand_in_lib}/log-records/presenters"
    cp "${BATS_TEST_DIRNAME}/write-presented-log-record.sh" "${stand_in_lib}/"

    cat > "${stand_in_lib}/log-records/presenters/resolve-log-presenter.sh" <<STUB
resolve_log_presenter() {
    log_presenter="${STAND_IN_PRESENTER}"
}
STUB

    export CALL_FILE="${BATS_TEST_TMPDIR}/run-stage-through-presenter.args"

    cat > "${stand_in_lib}/run-stage-through-presenter.sh" <<'STUB'
run_stage_through_presenter() {
    printf '%s\n' "$@" > "${CALL_FILE}"
    return "${STAGE_EXIT:-0}"
}
STUB

    # shellcheck source=SCRIPTDIR/write-presented-log-record.sh
    source "${stand_in_lib}/write-presented-log-record.sh"

    unset STAGE_EXIT
}

@test "runs the writer and its arguments through the picked presenter" {

    run --separate-stderr write_presented_log_record write_log_message "" "Dry run."

    [ "${status}" -eq 0 ]
    [ "$(cat "${CALL_FILE}")" = "${STAND_IN_PRESENTER}
write_log_message

Dry run." ]
}

@test "returns the status of the run through the presenter" {

    export STAGE_EXIT=3

    run --separate-stderr write_presented_log_record write_log_message "" "Dry run."

    [ "${status}" -eq 3 ]
}
