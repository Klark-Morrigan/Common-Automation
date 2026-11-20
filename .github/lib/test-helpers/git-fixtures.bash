#!/usr/bin/env bash
#
# Shared git fixtures for the git-backed bats suites.
#
# Sourced - never run -
# so it carries no tests itself,
# and it is not a *.bats file,
# so no bats run takes it for a suite.
#
# Lives under .github/lib/
# because the reusable workflows' second checkout already pulls that directory,
# so the suites run there find it at no extra sparse-checkout entry.

# shellcheck source=SCRIPTDIR/require-command.bash
source "${BASH_SOURCE[0]%/*}/require-command.bash"

# Skips the calling test when git is absent.
#
# The scripts under test are pure git behaviour,
# so without git there is nothing meaningful to assert.
#
require_git() {

    require_command git
}

# Creates an empty repo under BATS_TEST_TMPDIR,
# inits it, and cd's into it, setting REPO to its path.
#
# The throwaway location keeps every fixture isolated
# from the real repo and from other tests.
#
# Callers that operate on the repo by path (rather than cwd) use ${REPO};
# those that rely on cwd get it for free from the cd.
#
new_git_repo() {
    # shellcheck disable=SC2154 # bats sets BATS_TEST_TMPDIR for every test
    REPO="${BATS_TEST_TMPDIR}/repo"

    mkdir -p "${REPO}"
    git -C "${REPO}" init -q

    cd "${REPO}" \
        || return 1
}

# Creates an empty bare repo under BATS_TEST_TMPDIR,
# standing in for a GitHub remote,
# and sets REMOTE to its path.
#
# The scripts under test push to it;
# the suite reads the result back with git -C "${REMOTE}".
#
new_bare_remote() {
    # shellcheck disable=SC2154 # bats sets BATS_TEST_TMPDIR for every test
    REMOTE="${BATS_TEST_TMPDIR}/remote.git"

    git init -q --bare "${REMOTE}"
}

# Adds a tracked .sh file with an explicit git-index mode.
#
# --chmod sets the mode directly
# so the fixture does not depend on the host umask or core.fileMode
# (commonly false on Windows checkouts).
#
# $1 = filename,
# $2 = +x (executable, 100755) or -x (non-executable, 100644).
#
# Must run with cwd inside the repo (see new_git_repo).
#
add_tracked_sh() {

    local name="$1"
    local mode="$2"

    printf '#!/usr/bin/env bash\necho hi\n' > "${name}"

    git add "${name}"
    git update-index --chmod="${mode}" "${name}"
}

# Adds a tracked file written from a printf format string,
# so a test can pin the exact bytes at the end of each line.
#
# A whitespace fixture states its spaces as escapes, as in 'A line   \n',
# never as a literal line break after them:
# an editor trimming on save, or the trim itself,
# would quietly rewrite a literal one into a file with nothing wrong with it.
#
# $1 = filename, $2 = the content as a printf format string.
#
add_tracked_file() {

    local name="$1"
    local content="$2"

    printf '%b' "${content}" > "${name}"
    git add -- "${name}"
}

# Commits whatever is staged,
# so a test can stage a change against a HEAD.
#
# The identity is passed per call:
# a fixture repo has none of its own,
# and a CI runner has no global one.
#
commit_staged() {

    git -c user.email=t@t -c user.name=t commit -qm 'fixture'
}

# Prints the git-index mode of a tracked path:
# 100644 (no +x) or
# 100755 (+x).
#
# `git ls-files -s` emits "<mode> <object> <stage>\t<path>".
#
index_mode_of() {
    # shellcheck disable=SC2312 # a failed git prints no mode, which fails the caller's comparison
    git ls-files -s -- "$1" \
        | awk '{print $1}'
}
