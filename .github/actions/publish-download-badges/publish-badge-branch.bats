#!/usr/bin/env bats
# Unit tests for publish-badge-branch.sh.
# Run with: bats .github/actions/publish-download-badges/publish-badge-branch.bats
#
# A local bare repo stands in for the GitHub remote. A test-only git config
# rewrites the token-bearing GitHub URL the script builds to that repo, so
# each case also proves the URL's shape: any other URL misses the rewrite and
# fails to reach the network.

source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/git-fixtures.bash"

SCRIPT="${BATS_TEST_DIRNAME}/publish-badge-branch.sh"

REPOSITORY="owner/repo"
TOKEN="test-token"
BRANCH="badges"

setup() {

    require_git
    new_bare_remote

    # A config of the test's own, so the host's hooks, credential helpers and
    # line-ending settings cannot reach the script under test.
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL="${BATS_TEST_TMPDIR}/gitconfig"

    git config --file "${GIT_CONFIG_GLOBAL}" \
        "url.${REMOTE}.insteadOf" "https://x-access-token:${TOKEN}@github.com/${REPOSITORY}.git"

    export GIT_TERMINAL_PROMPT=0
    export GITHUB_REPOSITORY="${REPOSITORY}"
    export GH_TOKEN="${TOKEN}"
    export RETRY_MAX_ATTEMPTS=1

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

published_commit() {

    git -C "${REMOTE}" rev-parse "refs/heads/${BRANCH}"
}

published_commit_count() {

    git -C "${REMOTE}" rev-list --count "refs/heads/${BRANCH}"
}

published_file() {

    git -C "${REMOTE}" show "refs/heads/${BRANCH}:$1"
}

published_file_names() {

    git -C "${REMOTE}" ls-tree --name-only "refs/heads/${BRANCH}"
}

# Pushes one commit to master on the remote, standing in for the repository's
# own history.
seed_master() {

    new_git_repo
    printf 'source\n' > README.md

    git add README.md
    git -c user.name=Test -c user.email=test@example.com commit -qm "initial"
    git push -q "${REMOTE}" HEAD:refs/heads/master

    cd "${WORK_DIR}" || return 1
}

@test "creates the branch as a single commit on the first run" {

    render_file downloads.json '{"message":"44"}'
    publish

    [ "${status}" -eq 0 ]
    [ "$(published_commit_count)" -eq 1 ]
    [ "$(published_file downloads.json)" = '{"message":"44"}' ]
}

@test "leaves the commit alone when the files have not changed" {

    render_file downloads.json '{"message":"44"}'

    publish

    local first_commit
    first_commit="$(published_commit)"

    publish

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"nothing to publish"* ]]
    [ "$(published_commit)" = "${first_commit}" ]
}

@test "replaces the commit, still one, when a file changes" {

    render_file downloads.json '{"message":"44"}'

    publish

    local first_commit
    first_commit="$(published_commit)"
    render_file downloads.json '{"message":"45"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(published_commit)" != "${first_commit}" ]
    [ "$(published_commit_count)" -eq 1 ]
    [ "$(published_file downloads.json)" = '{"message":"45"}' ]
}

@test "drops a file deleted from the source directory" {

    render_file downloads.json '{"message":"44"}'
    render_file latest-version.json '{"message":"3"}'

    publish

    rm "${SOURCE_DIR}/latest-version.json"

    publish

    [ "${status}" -eq 0 ]
    [ "$(published_file_names)" = "downloads.json" ]
}

@test "leaves every other branch alone" {

    seed_master
    local master_commit
    master_commit="$(git -C "${REMOTE}" rev-parse refs/heads/master)"
    render_file downloads.json '{"message":"44"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(git -C "${REMOTE}" rev-parse refs/heads/master)" = "${master_commit}" ]
    [ "$(git -C "${REMOTE}" for-each-ref --format='%(refname)' refs/heads)" = "refs/heads/badges
refs/heads/master" ]
}

@test "refuses to overwrite figures another run published after the lookup" {

    render_file downloads.json '{"message":"44"}'
    publish
    new_git_repo
    printf '{"message":"45"}\n' > downloads.json

    git add downloads.json
    git -c user.name=Test -c user.email=test@example.com commit -qm "other run"

    local other_commit
    other_commit="$(git rev-parse HEAD)"
    cd "${WORK_DIR}" || return 1
    render_file downloads.json '{"message":"46"}'

    # A git on PATH that lands the other run's commit just before the push,
    # after the script has looked the branch up.
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    cat > "${BATS_TEST_TMPDIR}/bin/git" << EOF
#!/usr/bin/env bash
if [[ " \$* " == *" push "* ]]; then
    "$(command -v git)" -C "${REPO}" push -q --force "${REMOTE}" HEAD:refs/heads/${BRANCH}
fi
exec "$(command -v git)" "\$@"
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/git"

    PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"could not push badges to owner/repo"* ]]
    [ "$(published_commit)" = "${other_commit}" ]
}

@test "publishes as the workflow's bot identity" {

    render_file downloads.json '{"message":"44"}'

    publish

    [ "${status}" -eq 0 ]
    [ "$(git -C "${REMOTE}" log -1 --format='%an <%ae>' "refs/heads/${BRANCH}")" \
        = "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>" ]
}

@test "fails and publishes nothing when the source directory is empty" {

    publish

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"source directory '${SOURCE_DIR}' is empty"* ]]
    [ -z "$(git -C "${REMOTE}" for-each-ref refs/heads)" ]
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
    [ -z "$(git -C "${REMOTE}" for-each-ref refs/heads)" ]
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
