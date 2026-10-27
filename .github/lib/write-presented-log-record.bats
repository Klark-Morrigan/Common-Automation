#!/usr/bin/env bats
# Unit tests for write-presented-log-record.sh.
# Run with: bats .github/lib/write-presented-log-record.bats
#
# The function finds its collaborator beside its own file, so each case
# sources a copy of it from a stand-in lib tree. There resolve_log_presenter is
# a stub that picks a stand-in presenter, which marks every line it reads, so
# a case can see what reached it.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# What the stand-in presenter puts before each line it reads.
PRESENTED_PREFIX="presented: "

setup() {

    local stand_in_lib="${BATS_TEST_TMPDIR}/lib"

    mkdir -p "${stand_in_lib}"
    cp "${BATS_TEST_DIRNAME}/write-presented-log-record.sh" "${stand_in_lib}/"

    export STAND_IN_PRESENTER="${BATS_TEST_TMPDIR}/presenter.sh"

    cat > "${stand_in_lib}/resolve-log-presenter.sh" <<'STUB'
resolve_log_presenter() {
    log_presenter="${STAND_IN_PRESENTER}"
}
STUB

    cat > "${STAND_IN_PRESENTER}" <<STUB
#!/usr/bin/env bash
while IFS= read -r line; do
    printf '${PRESENTED_PREFIX}%s\n' "\${line}"
done
exit "\${PRESENTER_EXIT:-0}"
STUB
    chmod +x "${STAND_IN_PRESENTER}"

    # shellcheck source=SCRIPTDIR/write-presented-log-record.sh
    source "${stand_in_lib}/write-presented-log-record.sh"

    unset PRESENTER_EXIT WRITER_EXIT
}

# Stands in for a record writer: writes its arguments to stderr, one line, and
# a line to stdout that must not reach the log.
write_example_record() {

    echo "record: $*" >&2
    echo "not a log line"

    return "${WRITER_EXIT:-0}"
}

@test "sends the writer's record through the presenter, to stderr" {

    run --separate-stderr write_presented_log_record write_example_record "" "Dry run."

    [ "${status}" -eq 0 ]
    [ "${stderr}" = "${PRESENTED_PREFIX}record:  Dry run." ]
}

@test "keeps the writer's stdout out of the log and off stdout" {

    run --separate-stderr write_presented_log_record write_example_record "" "Dry run."

    [ -z "${output}" ]
    [[ "${stderr}" != *"not a log line"* ]]
}

@test "returns the writer's status when the writer fails" {

    export WRITER_EXIT=3

    run --separate-stderr write_presented_log_record write_example_record "" "Dry run."

    [ "${status}" -eq 3 ]
}

@test "returns the presenter's status when only the presenter fails" {

    export PRESENTER_EXIT=4

    run --separate-stderr write_presented_log_record write_example_record "" "Dry run."

    [ "${status}" -eq 4 ]
}
