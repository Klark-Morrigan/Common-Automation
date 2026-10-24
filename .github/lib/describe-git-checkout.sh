#!/usr/bin/env bash
# Describes a git checkout in one line. A script running code or reading files
# from a working tree says which code that was: the tree can sit on any
# branch, behind its remote, or hold uncommitted edits, where CI would use a
# clean checkout of the default branch. Sourced, not executed: defines
# describe_git_checkout.

# Prints "<dir>: <branch> at <commit>", with ", with uncommitted changes"
# appended when the tree has any, untracked files included. A detached head
# reads "detached at <commit>", a repository with no commit "no commits yet",
# and a directory outside any repository "not a git checkout".
#   describe_git_checkout <dir>
describe_git_checkout() {

    local dir="$1"
    local branch
    local commit
    local changes
    local state

    if ! git -C "${dir}" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        printf '%s: not a git checkout\n' "${dir}"
        return
    fi

    branch="$(git -C "${dir}" symbolic-ref --quiet --short HEAD || true)"
    commit="$(git -C "${dir}" rev-parse --quiet --verify --short HEAD || true)"
    changes="$(git -C "${dir}" status --porcelain)"

    if [[ -z "${commit}" ]]; then
        state="${branch:-detached}, no commits yet"
    elif [[ -n "${branch}" ]]; then
        state="${branch} at ${commit}"
    else
        state="detached at ${commit}"
    fi

    if [[ -n "${changes}" ]]; then
        state+=", with uncommitted changes"
    fi

    printf '%s: %s\n' "${dir}" "${state}"
}
