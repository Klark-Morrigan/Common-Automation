#!/usr/bin/env bats
# Tests for run-pre-commit-fixes.sh - the shared hook body. Each test drives a
# throwaway repo in BATS_TEST_TMPDIR, since the body reads what is staged out
# of git. The two fixes it calls have their own suites; what is pinned here is
# the wiring: both run, the +x set can be widened, and a tier's declared types
# are honoured when present and shrugged off when not.
#
# Whitespace fixtures state their spaces as printf escapes, never as a literal
# line break after them - see fix-trailing-whitespace.bats for why a suite
# about whitespace cannot keep any in its own source.

source "${BATS_TEST_DIRNAME}/test-helpers/git-fixtures.bash"

setup() {
    require_git
    SCRIPT="${BATS_TEST_DIRNAME}/run-pre-commit-fixes.sh"

    new_git_repo
}

add_tracked_file() {
    local name="$1" content="$2"
    printf '%b' "${content}" > "${name}"
    git add "${name}"
}

# A file declaring a further text type, standing in for Common-Java's.
write_tier_types_file() {
    printf "WHITESPACE_TRIMMED_TYPES+=('*.gradle')\n" > tier-types.sh
}

@test "applies both fixes in one run" {
    add_tracked_sh noexec.sh -x
    add_tracked_file notes.md 'A line   \n'

    # shellcheck source=./run-pre-commit-fixes.sh
    source "${SCRIPT}"
    run run_pre_commit_fixes
    [ "${status}" -eq 0 ]
    [ "$(index_mode_of noexec.sh)" = "100755" ]
    [ "$(cat notes.md)" = 'A line' ]
}

@test "leaves an unextensioned executable alone under the default +x rule" {
    add_tracked_sh gradlew -x

    # shellcheck source=./run-pre-commit-fixes.sh
    source "${SCRIPT}"
    run run_pre_commit_fixes
    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100644" ]
}

@test "honours a widened +x rule" {
    add_tracked_sh gradlew -x

    # shellcheck source=./run-pre-commit-fixes.sh
    source "${SCRIPT}"
    run run_pre_commit_fixes '(\.sh$|(^|/)gradlew$)'
    [ "${status}" -eq 0 ]
    [ "$(index_mode_of gradlew)" = "100755" ]
}

@test "trims a type a tier's declaration adds" {
    write_tier_types_file
    add_tracked_file build.gradle 'apply plugin: 3   \n'

    # shellcheck source=./run-pre-commit-fixes.sh
    source "${SCRIPT}"
    run run_pre_commit_fixes '\.sh$' tier-types.sh
    [ "${status}" -eq 0 ]
    [ "$(cat build.gradle)" = 'apply plugin: 3' ]
}

@test "commits fine when a tier's declaration is not checked out" {
    add_tracked_file notes.md 'A line   \n'
    add_tracked_file build.gradle 'apply plugin: 3   \n'

    # shellcheck source=./run-pre-commit-fixes.sh
    source "${SCRIPT}"
    run run_pre_commit_fixes '\.sh$' /nowhere/trimmed-file-types.sh
    [ "${status}" -eq 0 ]
    # The shared type is still trimmed; the tier's own is simply not.
    [ "$(cat notes.md)" = 'A line' ]
    [ "$(cat build.gradle)" = "$(printf 'apply plugin: 3   ')" ]
}

@test "is a silent no-op when nothing is staged" {
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
