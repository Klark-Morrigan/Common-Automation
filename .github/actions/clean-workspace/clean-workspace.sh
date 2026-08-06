#!/usr/bin/env bash
# Empties the runner workspace so a job starts from a known-clean
# directory.
#
# Why this is needed: a self-hosted runner keeps its _work/ tree between
# jobs, and actions/checkout only cleans the directory it checks out
# into. A job whose checkout sits in a subdirectory (checkout-path) is
# therefore free to trip over whatever the previous run left beside it.
# The sharpest form is a sibling clone: `git clone` refuses a
# destination that already exists, so every run after the first fails.
# GitHub-hosted runners get a fresh VM per job and never see this.
#
# Why it wipes wholesale rather than pruning known-stale names: it runs
# before any checkout, so nothing in the workspace is wanted yet. That
# ordering is reachable because a registry-form `uses:` is fetched into
# the runner's action cache rather than the workspace - the action is
# present with no checkout of its own.
#
# The workspace directory itself is kept. The runner creates it once per
# job and later steps expect it to exist, so only its contents go.

set -euo pipefail

root="${GITHUB_WORKSPACE:-}"

# This script's entire job is a recursive delete, so it refuses any
# value it cannot positively identify as a runner workspace rather than
# doing its best with a surprising one. A loud failure here is recoverable;
# a wrong delete on a persistent runner is not.
if [[ -z "${root}" ]]; then
    echo "::error::GITHUB_WORKSPACE is unset; refusing to clean an unknown directory."
    exit 1
fi

# Also the Windows guard: under Git Bash GITHUB_WORKSPACE arrives as
# D:\a\repo\repo, which fails this test and stops the script instead of
# letting a POSIX-shaped delete loose on a path it cannot reason about.
if [[ "${root}" != /* ]]; then
    echo "::error::GITHUB_WORKSPACE (${root}) is not an absolute POSIX path; refusing to clean it."
    exit 1
fi

if [[ "${root}" == "/" ]]; then
    echo "::error::GITHUB_WORKSPACE is the filesystem root; refusing to clean it."
    exit 1
fi

if [[ ! -d "${root}" ]]; then
    echo "Workspace ${root} does not exist yet - nothing to clean."
    exit 0
fi

# -mindepth 1 keeps ${root} itself while taking everything inside it,
# dotfiles included. -print names each entry in the job log before it
# goes, so a surprising delete is attributable after the fact. Handing
# the paths straight to -exec rather than reading them through a loop
# both sidesteps any quoting question about odd filenames and leaves
# find's own exit status in front of `set -e`.
find "${root}" -mindepth 1 -maxdepth 1 -print -exec rm -rf -- {} +

echo "Workspace ${root} is clean."
