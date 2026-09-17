#!/usr/bin/env bash
# Trims trailing spaces and tabs off the text files no other tool owns:
# Markdown prose and Gradle build scripts.
#
# Why those two and only those two. Trailing whitespace is invisible in an
# editor and loud in a diff - it lands as a changed line that says nothing,
# and it is the kind of change a reviewer has to read past. Java and Kotlin
# sources already have two owners in the JVM tier (Spotless rewrites them on
# demand, and Common-Java's enforceNoTrailingWhitespace gate reports them), so
# they are deliberately absent here: one file type with two rules is a rule
# nobody can predict. What was left over is prose and build scripts, which
# belong to no source set and so were reached by neither.
#
# Markdown carries one caveat worth stating. Two trailing spaces are a hard
# line break in Markdown, and trimming them changes how a file renders. No
# file in this family uses them - the house style breaks lines at punctuation
# instead - so trimming is safe here and would not be in a repo that did.
#
# Modes:
#
#   - Executed, no args:  trim every tracked file of those types (repo-wide).
#   - Executed, path args: trim only those paths, still filtered to the types
#     above, so a caller handing over a mixed list cannot widen the rule.
#   - Sourced: defines the three functions and runs nothing. The pre-commit
#     hooks source this and call fix_staged_trailing_whitespace.

set -euo pipefail

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# colorize + the TTY/NO_COLOR gate, so highlighting matches the other lib
# helpers rather than being re-derived here.
# shellcheck source=colors.sh
source "${lib_dir}/colors.sh"

# The file types this rule owns, as git pathspecs. The single source of the
# set: the repo-wide mode scans these, and the path-args mode filters down to
# them, so a hook can hand over everything it has staged without carrying its
# own copy of the list.
WHITESPACE_TRIMMED_TYPES=('*.md' '*.gradle')

# What counts as trailing whitespace, as one POSIX BRE shared by the detector
# and the fix so the two cannot come to disagree about it.
#
# Built from real characters rather than the escapes \t and \r: a POSIX basic
# regular expression has neither, and a grep or sed that reads them literally
# would hunt for the letters t and r instead. Space and tab only - never the
# newline, which cannot be matched line by line anyway - and a trailing CR is
# captured rather than eaten, so a file in a repo that has not pinned LF keeps
# the line ending it was checked out with.
whitespace_tab="$(printf '\t')"
whitespace_cr="$(printf '\r')"
TRAILING_WHITESPACE_PATTERN="[ ${whitespace_tab}]\{1,\}\(${whitespace_cr}\{0,1\}\)$"

# Every tracked file of an owned type that has a line ending in whitespace,
# one repo-root-relative path per line. No args scans the whole repo; paths
# narrow the scan to those, and are still held to the types above so a caller
# handing over a mixed list cannot widen the rule.
#
# Tracked files only, through git ls-files, so a build directory or an
# untracked scratch file is never rewritten. Read from the toplevel, since
# ls-files emits paths relative to it and grep has to resolve them the same
# way whatever directory the caller stood in.
#
# Newline-separated rather than NUL-separated, matching the +x engine beside
# this one: a NUL cannot be held in a shell variable, and capturing the list
# is what keeps git's exit status from being masked. git quotes a path with a
# newline in it, so such a path is skipped rather than mangled.
list_files_with_trailing_whitespace() {

    local repo_root listed file pattern matched
    local -a pathspecs

    repo_root="$(git rev-parse --show-toplevel)"

    if (( $# > 0 )); then
        pathspecs=("$@")
    else
        pathspecs=("${WHITESPACE_TRIMMED_TYPES[@]}")
    fi

    listed="$(cd "${repo_root}" && git ls-files -- "${pathspecs[@]}")"

    if [[ -z "${listed}" ]]; then
        return 0
    fi

    while IFS= read -r file; do

        # Glob-matched against the type set rather than compared by extension,
        # so that set can stay written as the pathspecs git reads above.
        matched=''

        for pattern in "${WHITESPACE_TRIMMED_TYPES[@]}"; do
            # shellcheck disable=SC2053 # the right side is a pattern on purpose
            if [[ "${file}" == ${pattern} ]]; then
                matched='yes'
                break
            fi
        done

        if [[ -z "${matched}" ]]; then
            continue
        fi

        # -I so a file that is binary despite its name is skipped rather than
        # reported as one long match.
        if grep -qI -- "${TRAILING_WHITESPACE_PATTERN}" "${repo_root}/${file}"; then
            echo "${file}"
        fi
    done <<< "${listed}"
}

# Rewrites the offenders among the given paths (no args = the whole repo),
# printing each. A no-op when nothing offends. Returns 0 either way.
fix_trailing_whitespace() {

    local repo_root offenders file line

    repo_root="$(git rev-parse --show-toplevel)"
    offenders="$(list_files_with_trailing_whitespace "$@")"

    if [[ -z "${offenders}" ]]; then
        return 0
    fi

    # Highlighted in green so the rewrite stands out in a hook's output and in
    # the menu runner. colorize (lib/colors.sh) owns the TTY/NO_COLOR gate, so
    # a piped or captured stream stays plain ASCII. It emits no trailing
    # newline, being a composable building block, so the line is captured and
    # echoed rather than echo-ing a command substitution (SC2005/SC2312).
    while IFS= read -r file; do

        line="$(colorize green "trimming trailing whitespace in ${file}")"
        echo "${line}"

        (cd "${repo_root}" && sed -i "s/${TRAILING_WHITESPACE_PATTERN}/\\1/" "${file}")
    done <<< "${offenders}"
}

# The pre-commit entry point: trims what is being committed and re-stages it,
# so every repo's hook is one call rather than a copy of this policy.
#
# A path with unstaged changes beside its staged ones is named and left alone.
# This fix rewrites file CONTENT, unlike the +x one next to it, so re-adding
# such a file would sweep the author's unstaged hunks into the commit - a hook
# that quietly commits work nobody asked it to commit is worse than a hook
# that leaves one line of whitespace behind.
fix_staged_trailing_whitespace() {

    local staged offenders file
    local -a staged_paths trimmable

    # --diff-filter=AM: Added and Modified. A deleted path has no content to
    # trim, and a rename with no edit carries none of its own.
    staged="$(git diff --cached --name-only --diff-filter=AM)"

    if [[ -z "${staged}" ]]; then
        return 0
    fi

    readarray -t staged_paths <<< "${staged}"

    offenders="$(list_files_with_trailing_whitespace "${staged_paths[@]}")"
    trimmable=()

    while IFS= read -r file; do

        if [[ -z "${file}" ]]; then
            continue
        fi

        if git diff --quiet -- "${file}"; then
            trimmable+=("${file}")
        else
            echo "trailing whitespace left in ${file}: it has unstaged changes, so it was not re-staged"
        fi
    done <<< "${offenders}"

    if (( ${#trimmable[@]} == 0 )); then
        return 0
    fi

    fix_trailing_whitespace "${trimmable[@]}"
    git add -- "${trimmable[@]}"
}

# Sourced? Expose the functions and return - skip the run.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

fix_trailing_whitespace "$@"
