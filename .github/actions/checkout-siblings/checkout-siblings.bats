#!/usr/bin/env bats
# Unit tests for checkout-siblings.sh.
# Run with: bats .github/actions/checkout-siblings/checkout-siblings.bats
#
# git is stubbed on PATH: the stub records the arguments of every call to a log
# file, and the header config it was handed to another, and creates the
# destination directory, so a case can assert what would have been cloned
# without reaching the network.

# run ! arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/path-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/path-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/checkout-siblings.sh"

# "x-access-token:s3cret" in base64.
ENCODED_CREDENTIAL="eC1hY2Nlc3MtdG9rZW46czNjcmV0"

setup() {

    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "${WORK_DIR}"
    export GIT_LOG="${WORK_DIR}/git-calls.log"
    export GIT_HEADER_LOG="${WORK_DIR}/git-headers.log"

    unset GITHUB_ACTIONS

    install_path_stub git <<'EOF'
#!/bin/sh
echo "$*" >> "$GIT_LOG"
echo "${GIT_CONFIG_KEY_0:-}=${GIT_CONFIG_VALUE_0:-}" >> "$GIT_HEADER_LOG"
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

@test "authenticates each clone with a header for its repository alone" {

    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"},{"repo":"owner/two","path":"two"}]' GH_TOKEN='s3cret' \
        run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${GIT_HEADER_LOG}")" = "http.https://github.com/owner/one.git.extraheader=AUTHORIZATION: basic ${ENCODED_CREDENTIAL}
http.https://github.com/owner/two.git.extraheader=AUTHORIZATION: basic ${ENCODED_CREDENTIAL}" ]
}

# A command line is readable by every user on the runner.
@test "keeps the token off git's command line" {

    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"}]' GH_TOKEN='s3cret' run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    run ! grep -qF "s3cret" "${GIT_LOG}"
    run ! grep -qF "${ENCODED_CREDENTIAL}" "${GIT_LOG}"
}

# git writes the clone URL into .git/config, which on a self-hosted runner
# outlives the job, so the URL never carries the token.
@test "clones from the plain URL, with nothing to rewrite after" {

    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"}]' GH_TOKEN='s3cret' run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(cat "${GIT_LOG}")" = "clone --depth 1 https://github.com/owner/one.git one" ]
}

# The script reads every entry with jq, so jq shows what a process other than
# git is handed.
@test "keeps the token from every process but git" {

    install_environment_recording_command jq

    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"}]' GH_TOKEN='s3cret' run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -s "${BATS_TEST_TMPDIR}/jq.environment" ]
    run ! grep -qF "s3cret" "${BATS_TEST_TMPDIR}/jq.environment"
    run ! grep -qF "${ENCODED_CREDENTIAL}" "${BATS_TEST_TMPDIR}/jq.environment"
}

# Actions masks the token in its log, but not its encoding.
@test "under GitHub Actions, masks the encoded credential" {

    cd "${WORK_DIR}"
    SIBLINGS='[{"repo":"owner/one","path":"one"}]' GH_TOKEN='s3cret' GITHUB_ACTIONS=true run bash "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"::add-mask::${ENCODED_CREDENTIAL}"* ]]
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
