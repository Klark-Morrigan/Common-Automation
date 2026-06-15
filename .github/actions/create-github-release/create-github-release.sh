#!/usr/bin/env bash
# Creates a GitHub Release for a tag, with the body taken from the matching
# CHANGELOG.md section (Keep a Changelog format). Stack-agnostic: it needs
# only a changelog file and an existing tag, so a PowerShell module, a
# NuGet package, or any other artifact stream can reuse it unchanged.
#
# Inputs are read from the environment (set by action.yml):
#   CHANGELOG   Path to the changelog file.        Default: CHANGELOG.md
#   VERSION     Version to release.                Default: the topmost
#               '## [X.Y.Z]' section (skipping '## [Unreleased]').
#   TAG         Git tag to attach the release to.  Default: VERSION
#   DRAFT       'true' to create a draft release.  Default: false
#   PRERELEASE  'true' to mark as a prerelease.    Default: false
#
# Requires gh on PATH and GH_TOKEN in the environment, plus the caller's
# workflow granting 'permissions: contents: write'. Fails if the resolved
# version has no changelog section, so a release can never ship with empty
# notes.

set -euo pipefail

changelog="${CHANGELOG:-CHANGELOG.md}"
version="${VERSION:-}"
tag="${TAG:-}"
draft="${DRAFT:-false}"
prerelease="${PRERELEASE:-false}"

if [[ ! -f "${changelog}" ]]; then
    echo "::error::create-github-release: changelog not found at '${changelog}'." >&2
    exit 1
fi

# Resolve the version from the first real version heading when not supplied.
# The grep skips '## [Unreleased]' (no leading digit); '|| true' keeps a
# no-match from tripping 'set -e' so the explicit guard below owns the error.
if [[ -z "${version}" ]]; then
    version="$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+' "${changelog}" \
        | sed -E 's/^## \[([^]]+)\].*/\1/' || true)"
fi
if [[ -z "${version}" ]]; then
    echo "::error::create-github-release: no '## [X.Y.Z]' version heading in '${changelog}' and no VERSION input." >&2
    exit 1
fi

tag="${tag:-${version}}"

# Slice the section: lines after the '## [version]' heading up to (but not
# including) the next '## [' heading, with the surrounding blank lines
# trimmed. POSIX awk only - no gawk match() array, so it runs on the BSD awk
# of macOS runners as well as GNU awk.
notes="$(awk -v ver="${version}" '
    $0 ~ "^## \\[" ver "\\]" { capture = 1; next }
    capture && /^## \[/      { exit }
    capture                  { body = body $0 "\n" }
    END {
        gsub(/^[ \t\r\n]+/, "", body)
        gsub(/[ \t\r\n]+$/, "", body)
        printf "%s", body
    }
' "${changelog}")"

if [[ -z "${notes//[[:space:]]/}" ]]; then
    echo "::error::create-github-release: no changelog entry for version '${version}' in '${changelog}'. Add a '## [${version}]' section before releasing." >&2
    exit 1
fi

create_args=( release create "${tag}" --title "${version}" --notes "${notes}" --verify-tag )
[[ "${draft}" == "true" ]]      && create_args+=( --draft )
[[ "${prerelease}" == "true" ]] && create_args+=( --prerelease )

echo "create-github-release: creating release for tag '${tag}' (version '${version}') from '${changelog}'."
gh "${create_args[@]}"
