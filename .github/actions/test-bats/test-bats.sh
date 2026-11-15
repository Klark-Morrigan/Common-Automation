#!/usr/bin/env bash
# Runs every bats suite git tracks under a directory, with the bats already
# on PATH.
#
# Discovery is list_bats_suites, not `bats --recursive`: a consumer's CI
# workspace holds the .common-automation checkout of this repo, and a
# recursive walk ran that copy's suites as the consumer's own.
#
# Skips with a `::notice::` when no suite is tracked under the path, since
# bats handed no files fails rather than passing.
#
# Usage: ./test-bats.sh <scan-path>

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=SCRIPTDIR/../../lib/list-bats-suites.sh
source "${script_dir}/../../lib/list-bats-suites.sh"

scan_path="${1:?usage: test-bats.sh <scan-path>}"

# Checked first because the discovery below cannot tell "not a repo" from
# "no suites" once git's exit status is lost in the process substitution.
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "::error::${PWD} is not a git work tree; the bats run covers the suites git tracks."
    exit 1
fi

# SC2312: git's exit status is masked here; the work-tree check above
# covers the only failure that matters.
# shellcheck disable=SC2312
mapfile -t suites < <(list_bats_suites "${scan_path}")

if (( ${#suites[@]} == 0 )); then
    echo "::notice::git tracks no bats suites under ${scan_path}, skipping"
    exit 0
fi

echo "Running ${#suites[@]} suite(s) under ${scan_path}."

exec bats "${suites[@]}"
