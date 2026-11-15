#!/usr/bin/env bash
# Lists the bats suites a test run covers under a directory. Sourced, not
# executed: defines list_bats_suites.
#
# Only the suites git tracks count. A consumer's CI workspace also holds the
# .common-automation checkout of this repo, and a recursive walk ran that
# copy's suites as the consumer's own. Generated and vendored trees are
# untracked too, so the tracked suites are exactly the repo's own.

# Prints each tracked *.bats under <dir>, as git names it relative to the
# current directory, one per line, sorted. Prints nothing when there is none.
#
# Names the untracked suites it leaves out on stderr, so a suite someone
# forgot to add is seen to be skipped rather than silently passing. A nested
# checkout is never listed: git treats it as one untracked directory.
#   list_bats_suites <dir>
list_bats_suites() {

    local scan_dir="$1"
    local tracked_suites=()
    local untracked_suites=()
    local joined_suites
    local suite

    # git pathspec `*` also matches `/`, so the pattern reaches every depth.
    # SC2312: git's exit status is masked here; a caller checks for a work
    # tree first, which covers the only failure that matters.
    # shellcheck disable=SC2312
    mapfile -d '' -t tracked_suites < <(git ls-files -z -- "${scan_dir}/*.bats")
    # shellcheck disable=SC2312
    mapfile -d '' -t untracked_suites < <(git ls-files -z --others --exclude-standard -- "${scan_dir}/*.bats")

    for suite in "${tracked_suites[@]}"; do

        # A tracked suite deleted from the work tree is a removal not yet staged.
        if [[ -f "${suite}" ]]; then
            printf '%s\n' "${suite}"
        fi
    done

    if (( ${#untracked_suites[@]} > 0 )); then

        printf -v joined_suites '%s, ' "${untracked_suites[@]}"
        echo "Leaving out the suites under ${scan_dir} that git does not track: ${joined_suites%, }." >&2
    fi
}
