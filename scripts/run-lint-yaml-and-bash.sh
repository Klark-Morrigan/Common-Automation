#!/usr/bin/env bash
#
# Runs the lint half of this repo's CI locally, under the entry name every
# repo's scripts/ carries. A consumer's shim reaches the half through its
# imports/; this repo owns the half, so the shim hands off directly.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${script_dir}/_run-lint-yaml-and-bash.sh"
