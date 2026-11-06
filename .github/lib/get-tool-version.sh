#!/usr/bin/env bash
# Prints the version pinned for one tool: an explicit override argument
# wins, otherwise the tool's key in the adjacent versions.env. The one
# accessor for every pin, so CI and the local runners cannot read
# different versions, and only this file knows the versions.env format.
#
# Usage: get-tool-version.sh <NAME>_VERSION [override]
#   <NAME>_VERSION  The versions.env key, such as YAMLLINT_VERSION. Callers
#                   name the key in full, so a search for it finds them.
#   [override]      Optional explicit version; echoed verbatim when
#                   non-empty, in which case versions.env is not read.

set -euo pipefail

# The key is looked up indirectly, and Bash evaluates an array subscript
# in an indirect name: 'X[$(cmd)]' would run cmd. Only a plain key passes.
readonly KEY_PATTERN='^[A-Z][A-Z0-9_]*_VERSION$'

key="${1:-}"
override="${2:-}"

if [[ ! "${key}" =~ ${KEY_PATTERN} ]]; then
    echo "get-tool-version: usage: get-tool-version.sh <NAME>_VERSION [override]; got '${key}'" >&2
    exit 2
fi

if [[ -n "${override}" ]]; then
    printf '%s\n' "${override}"
    exit 0
fi

versions_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/versions.env"

# A same-named variable inherited from the caller must not stand in for a
# missing pin. bats, for one, exports BATS_VERSION.
unset "${key}"

# shellcheck source=SCRIPTDIR/versions.env
source "${versions_file}"

if [[ -z "${!key:-}" ]]; then
    echo "get-tool-version: ${key} is not set in ${versions_file}" >&2
    exit 1
fi

printf '%s\n' "${!key}"
