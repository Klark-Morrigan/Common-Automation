#!/usr/bin/env bats
# Unit tests for publish-badge-branch.sh.
# Run with: bats .github/actions/publish-download-badges/publish-badge-branch.bats
#
# A local bare repo stands in for the GitHub remote. A test-only git config
# rewrites the GitHub URL the script builds to that repo, so each case also
# proves the URL's shape: any other URL misses the rewrite and fails to reach
# the network. A local remote ignores HTTP headers, so the token's header is
# asserted on what git was handed instead.

# run ! arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=../../lib/test-helpers/git-fixtures.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/git-fixtures.bash"

# shellcheck source=../../lib/test-helpers/path-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/path-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/publish-badge-branch.sh"

REPOSITORY="owner/repo"
TOKEN="test-token"
BRANCH="badges"

setup() {

    require_git
    new_bare_remote

    # A config of the test's own, so the host's hooks, credential helpers and
    # line-ending settings cannot reach the script under test. The identity
    # signs the commits a case makes itself; the script names its own.
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL="${BATS_TEST_TMPDIR}/gitconfig"

    git config --file "${GIT_CONFIG_GLOBAL}" \
        "url.${REMOTE}.insteadOf" "https://github.com/${REPOSITORY}.git"
    git config --file "${GIT_CONFIG_GLOBAL}" user.name "Test"
    git config --file "${GIT_CONFIG_GLOBAL}" user.email "test@example.com"

    export GITHUB_REPOSITORY="${REPOSITORY}"
    export GH_TOKEN="${TOKEN}"
    export RETRY_MAX_ATTEMPTS=1

    # Set when the suite itself runs in Actions; a case opts in to it.
    unset GITHUB_ACTIONS

    SOURCE_DIR="${BATS_TEST_TMPDIR}/rendered"
    mkdir -p "${SOURCE_DIR}"

    # Outside any repository, so a case passing proves the script needs no
    # checkout of its own.
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "${WORK_DIR}"
    cd "${WORK_DIR}" || return 1
}

# Writes one rendered file into the source directory.
render_file() {

    printf '%s\n' "$2" > "${SOURCE_DIR}/$1"
}

publish() {

    run "${SCRIPT}" "${SOURCE_DIR}" "${BRANCH}"
}

read_published_commit() {

    git -C "${REMOTE}" rev-parse "refs/heads/${BRANCH}"
}

count_published_commits() {

    git -C "${REMOTE}" rev-list --count "refs/heads/${BRANCH}"
}

read_published_file() {

    git -C "${REMOTE}" show "refs/heads/${BRANCH}:$1"
}

list_published_file_names() {

    git -C "${REMOTE}" ls-tree --name-only "refs/heads/${BRANCH}"
}

list_remote_branches() {

    git -C "${REMOTE}" for-each-ref --format='%(refname)' refs/heads
}

# Commits one file in a fresh scratch repo, left at ${REPO}, then returns to
# the work directory.
commit_in_scratch_repo() {

    new_git_repo
    printf '%s\n' "$2" > "$1"

    git add "$1"
    git commit -qm "scratch"

    cd "${WORK_DIR}" || return 1
}

# Puts a git on PATH that pushes the scratch repo's commit to the branch just
# before any push of the script's own, after its lookup: a second run
# publishing in between.
install_racing_git() {

    local real_git

    real_git="$(command -v git)"

    install_path_stub git <<STUB
#!/usr/bin/env bash
if [[ " \$* " == *" push "* ]]; then
    "${real_git}" -C "${REPO}" push -q --force "${REMOTE}" HEAD:refs/heads/${BRANCH}
fi
exec "${real_git}" "\$@"
STUB
}

# Puts a git on PATH that records, for every call, its arguments in
# ${GIT_ARGS_FILE} and its environment config in ${GIT_ENV_CONFIG_FILE}, one
# line per call each, then runs the real git.
install_recording_git() {

    local real_git

    real_git="$(command -v git)"

    export GIT_ARGS_FILE="${BATS_TEST_TMPDIR}/git.args"
    export GIT_ENV_CONFIG_FILE="${BATS_TEST_TMPDIR}/git.env-config"

    install_path_stub git <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${GIT_ARGS_FILE}"
printf '%s=%s\n' "\${GIT_CONFIG_KEY_0:-}" "\${GIT_CONFIG_VALUE_0:-}" >> "${GIT_ENV_CONFIG_FILE}"
exec "${real_git}" "\$@"
STUB
}

# Prints the token's HTTP Basic credentials, as GitHub expects them.
encode_token_credential() {

    printf 'x-access-token:%s' "${TOKEN}" | base64 | tr -d '\n'
}

@test "creates the branch as a single commit on the first run" {

    render_file downloads.json '{"message":"44"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(count_published_commits)" -eq 1 ]
    [ "$(read_published_file downloads.json)" = '{"message":"44"}' ]
}

@test "leaves the commit alone when the files have not changed" {

    render_file downloads.json '{"message":"44"}'
    publish
    local first_commit
    first_commit="$(read_published_commit)"

    publish

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"nothing to publish"* ]]
    [ "$(read_published_commit)" = "${first_commit}" ]
}

@test "replaces the commit, still one, when a file changes" {

    render_file downloads.json '{"message":"44"}'
    publish
    local first_commit
    first_commit="$(read_published_commit)"
    render_file downloads.json '{"message":"45"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(read_published_commit)" != "${first_commit}" ]
    [ "$(count_published_commits)" -eq 1 ]
    [ "$(read_published_file downloads.json)" = '{"message":"45"}' ]
}

@test "adds a file beside the published ones" {

    render_file downloads.json '{"message":"44"}'
    publish

    render_file latest-version.json '{"message":"3"}'
    publish

    [ "${status}" -eq 0 ]
    [ "$(list_published_file_names)" = "downloads.json
latest-version.json" ]
}

@test "refuses to withdraw a published file, leaving the branch as it was" {

    render_file downloads.json '{"message":"44"}'
    render_file latest-version.json '{"message":"3"}'
    render_file adoption-latest.json '{"message":"2/day"}'

    publish

    local first_commit
    first_commit="$(read_published_commit)"
    rm "${SOURCE_DIR}/latest-version.json" "${SOURCE_DIR}/adoption-latest.json"
    render_file downloads.json '{"message":"45"}'

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"serves adoption-latest.json, latest-version.json, which this run did not render"* ]]
    [ "$(read_published_commit)" = "${first_commit}" ]
}

@test "publishes without a file deleted from the branch by hand" {

    render_file downloads.json '{"message":"44"}'
    render_file latest-version.json '{"message":"3"}'

    publish

    commit_in_scratch_repo downloads.json '{"message":"44"}'
    git -C "${REPO}" push -q --force "${REMOTE}" "HEAD:refs/heads/${BRANCH}"
    rm "${SOURCE_DIR}/latest-version.json"
    render_file downloads.json '{"message":"45"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(list_published_file_names)" = "downloads.json" ]
    [ "$(read_published_file downloads.json)" = '{"message":"45"}' ]
}

@test "leaves every other branch alone" {

    commit_in_scratch_repo README.md source
    git -C "${REPO}" push -q "${REMOTE}" HEAD:refs/heads/master
    local master_commit
    master_commit="$(git -C "${REMOTE}" rev-parse refs/heads/master)"
    render_file downloads.json '{"message":"44"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(git -C "${REMOTE}" rev-parse refs/heads/master)" = "${master_commit}" ]
    [ "$(list_remote_branches)" = "refs/heads/badges
refs/heads/master" ]
}

@test "refuses to overwrite figures another run published after the lookup" {

    render_file downloads.json '{"message":"44"}'

    publish

    commit_in_scratch_repo downloads.json '{"message":"45"}'
    local other_commit
    other_commit="$(git -C "${REPO}" rev-parse HEAD)"
    render_file downloads.json '{"message":"46"}'
    install_racing_git

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"could not push badges to owner/repo"* ]]
    [ "$(read_published_commit)" = "${other_commit}" ]
}

@test "publishes as the workflow's bot identity" {

    render_file downloads.json '{"message":"44"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(git -C "${REMOTE}" log -1 --format='%an <%ae>' "refs/heads/${BRANCH}")" \
        = "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>" ]
}

@test "sends the token in a header, never on a command line" {

    render_file downloads.json '{"message":"44"}'
    install_recording_git

    publish

    [ "${status}" -eq 0 ]
    grep -qxF "http.https://github.com/.extraheader=AUTHORIZATION: basic $(encode_token_credential)" \
        "${GIT_ENV_CONFIG_FILE}"
    run ! grep -qF "${TOKEN}" "${GIT_ARGS_FILE}"
}

@test "masks the encoded token in an Actions log" {

    render_file downloads.json '{"message":"44"}'
    export GITHUB_ACTIONS=true

    publish

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"::add-mask::$(encode_token_credential)"* ]]
}

@test "keeps the encoded token out of a local run's output" {

    render_file downloads.json '{"message":"44"}'

    publish

    [ "${status}" -eq 0 ]
    [[ "${output}" != *"$(encode_token_credential)"* ]]
}

@test "fails and publishes nothing when the source directory is empty" {

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"source directory '${SOURCE_DIR}' holds no file"* ]]
    [ -z "$(list_remote_branches)" ]
}

@test "fails and publishes nothing when the source directory holds only empty folders" {

    # git stages files only, so these would publish an empty branch.
    mkdir -p "${SOURCE_DIR}/nested/deeper"

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"source directory '${SOURCE_DIR}' holds no file"* ]]
    [ -z "$(list_remote_branches)" ]
}

@test "fails when the source directory does not exist" {

    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/missing" "${BRANCH}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"source directory '${BATS_TEST_TMPDIR}/missing' does not exist"* ]]
}

@test "fails and publishes nothing when the branch name is invalid" {

    render_file downloads.json '{"message":"44"}'
    run "${SCRIPT}" "${SOURCE_DIR}" "bad..name"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"'bad..name' is not a valid branch name"* ]]
    [ -z "$(list_remote_branches)" ]
}

@test "fails when the remote cannot be read" {

    render_file downloads.json '{"message":"44"}'
    rm -rf "${REMOTE}"

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"could not look up badges on owner/repo"* ]]
}

@test "requires the source directory" {

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"source directory required"* ]]
}

@test "requires the branch" {

    run "${SCRIPT}" "${SOURCE_DIR}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"branch required"* ]]
}

@test "requires GITHUB_REPOSITORY" {

    unset GITHUB_REPOSITORY

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"GITHUB_REPOSITORY is required"* ]]
}

@test "requires GH_TOKEN" {

    unset GH_TOKEN

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"GH_TOKEN is required"* ]]
}
