#!/usr/bin/env bats
# Unit tests for checkout-siblings.sh.
# Run with: bats .github/actions/checkout-siblings/checkout-siblings.bats
#
# git is stubbed by writing a shell script into a temporary directory that is
# prepended to PATH: it records the arguments of every call to a log file and
# creates the destination directory, so a case can assert what would have been
# cloned without reaching the network.

SCRIPT="${BATS_TEST_DIRNAME}/checkout-siblings.sh"

setup() {
    STUBS_DIR="$(mktemp -d)"
    WORK_DIR="$(mktemp -d)"
    export GIT_LOG="${WORK_DIR}/git-calls.log"
    export PATH="${STUBS_DIR}:${PATH}"

    cat > "${STUBS_DIR}/git" <<'EOF'
#!/bin/sh
echo "$*" >> "$GIT_LOG"
# Create the clone destination so a later `git -C <path>` call is plausible
# and a second entry cloning into the same name would collide, as git would.
case "$1" in
  clone)
    for arg in "$@"; do last="$arg"; done
    mkdir -p "$last"
    ;;
esac
exit 0
EOF
    chmod +x "${STUBS_DIR}/git"
}

teardown() {
    rm -rf "${STUBS_DIR}" "${WORK_DIR}"
}

@test "clones nothing when no siblings are given" {
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -f "${GIT_LOG}" ]
}

@test "clones nothing for an empty array" {
    SIBLINGS='[]' run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -f "${GIT_LOG}" ]
}

@test "clones nothing for an empty string" {
    SIBLINGS='' run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -f "${GIT_LOG}" ]
}

@test "clones each entry shallowly" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"},{"repo":"owner/two","path":"two"}]' \
        run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "clone --depth 1 .*owner/one.git one" "${GIT_LOG}"
    grep -q "clone --depth 1 .*owner/two.git two" "${GIT_LOG}"
}

@test "passes the ref as a branch when one is given" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","ref":"v2","path":"one"}]' run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q -- "--branch v2" "${GIT_LOG}"
}

@test "omits --branch entirely when no ref is given" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"}]' run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    ! grep -q -- "--branch" "${GIT_LOG}"
}

@test "authenticates the clone with the given token" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"}]' GH_TOKEN='s3cret' run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "x-access-token:s3cret@github.com/owner/one.git" "${GIT_LOG}"
}

# The clone URL carries the token into the clone's .git/config, and on a
# self-hosted runner that file outlives the job.
@test "rewrites the remote so the token is not left on disk" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"}]' GH_TOKEN='s3cret' run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q -- "-C one remote set-url origin https://github.com/owner/one.git" "${GIT_LOG}"
    # The rewritten URL is the token-free one.
    ! grep -q "set-url origin.*s3cret" "${GIT_LOG}"
}

@test "refuses an absolute sibling path" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"/etc/cron.d"}]' run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"unsafe sibling path"* ]]
    [ ! -f "${GIT_LOG}" ]
}

@test "refuses a sibling path escaping the workspace" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"../elsewhere"}]' run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"unsafe sibling path"* ]]
    [ ! -f "${GIT_LOG}" ]
}

@test "refuses an empty sibling path" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one"}]' run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"unsafe sibling path"* ]]
}

@test "refuses an entry stating no repo" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"path":"one"}]' run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"states no repo"* ]]
}

# A rejected entry must stop the run rather than leaving the loop to clone
# whatever came after it - the failure mode a piped `while` subshell has.
@test "clones nothing after refusing an entry" {
    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"../escape"},{"repo":"owner/two","path":"two"}]' \
        run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [ ! -f "${GIT_LOG}" ]
}

@test "fails when siblings is not a JSON array" {
    cd "${WORK_DIR}"
    SIBLINGS='{"repo":"owner/one"}' run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"must be a JSON array"* ]]
}

@test "fails when siblings is not JSON at all" {
    cd "${WORK_DIR}"
    SIBLINGS='owner/one' run bash "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"must be a JSON array"* ]]
}
