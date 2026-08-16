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
#   FILES       Newline-separated asset paths to attach. Default: none
#   NOTES_SUFFIX Markdown appended below the changelog section, under a
#               horizontal rule. Trimmed at both ends, and treated as
#               absent when it holds nothing but whitespace, so a workflow
#               expression can be passed through as-is. Default: none,
#               leaving the body as the changelog section alone.
#
# Requires gh on PATH and GH_TOKEN in the environment, plus the caller's
# workflow granting 'permissions: contents: write'. Fails if the resolved
# version has no changelog section, so a release can never ship with empty
# notes.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve the changelog helpers: COMMON_AUTOMATION_REPO_ROOT is authoritative
# when the composite exports it; the relative fallback resolves the same file
# from this action's own location otherwise. Mirrors action-validator.sh.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"
# shellcheck source=../../lib/changelog.sh
source "${repo_root}/.github/lib/changelog.sh"

# Echoes $1 with whitespace trimmed from both ends. Written as a named
# function because the parameter-expansion form that does this reads as
# line noise, and because what it protects against is not obvious: a suffix
# arrives from a workflow expression, which routinely carries a leading or
# trailing newline from a YAML folded scalar, and appending that untrimmed
# renders as blank lines between the rule and the text.
trim_surrounding_whitespace() {
    local text="${1}"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    printf '%s' "${text}"
}

changelog="${CHANGELOG:-CHANGELOG.md}"
version="${VERSION:-}"
tag="${TAG:-}"
draft="${DRAFT:-false}"
prerelease="${PRERELEASE:-false}"
files="${FILES:-}"
# Trimmed on the way in, which also settles the empty case: a suffix of
# nothing but whitespace trims to nothing, so the append below tests for a
# plain empty string rather than repeating a strip-and-compare.
notes_suffix="$(trim_surrounding_whitespace "${NOTES_SUFFIX:-}")"

# Blank lines on both sides of the rule are not cosmetic. In Markdown a line
# of dashes directly under text makes that text a heading (setext form), so
# without the leading blank line the changelog's last line would silently
# render as an H2 in the published release.
readonly NOTES_SUFFIX_SEPARATOR=$'\n\n---\n\n'

if [[ ! -f "${changelog}" ]]; then
    echo "::error::create-github-release: changelog not found at '${changelog}'." >&2
    exit 1
fi

# Resolve the version from the changelog's latest section when not supplied.
if [[ -z "${version}" ]]; then
    version="$(changelog_latest_version "${changelog}")"
fi
if [[ -z "${version}" ]]; then
    echo "::error::create-github-release: no '## [X.Y.Z]' version heading in '${changelog}' and no VERSION input." >&2
    exit 1
fi

tag="${tag:-${version}}"

notes="$(changelog_section "${changelog}" "${version}")"

if [[ -z "${notes//[[:space:]]/}" ]]; then
    echo "::error::create-github-release: no changelog entry for version '${version}' in '${changelog}'. Add a '## [${version}]' section before releasing." >&2
    exit 1
fi

# Appended below the notes rather than merged into them, so the changelog
# section stays exactly what the repository wrote while a caller adds
# release-time context the changelog cannot know - a link to the build it was
# produced by, the upstream release it was built against, and so on. A suffix
# of nothing but whitespace is treated as absent, so a caller passing an
# expression that resolved to empty gets the plain body rather than a stray
# rule under it.
if [[ -n "${notes_suffix}" ]]; then
    notes="${notes}${NOTES_SUFFIX_SEPARATOR}${notes_suffix}"
fi

create_args=( release create "${tag}" --title "${version}" --notes "${notes}" --verify-tag )
[[ "${draft}" == "true" ]]      && create_args+=( --draft )
[[ "${prerelease}" == "true" ]] && create_args+=( --prerelease )

# Attach asset files when supplied. gh takes asset paths as trailing
# positional args, so they go after the flags. Each non-blank line of FILES is
# one asset; empty FILES leaves the release asset-less (historical behaviour).
if [[ -n "${files//[[:space:]]/}" ]]; then
    while IFS= read -r asset; do
        [[ -n "${asset//[[:space:]]/}" ]] && create_args+=( "${asset}" )
    done <<< "${files}"
fi

echo "create-github-release: creating release for tag '${tag}' (version '${version}') from '${changelog}'."
gh "${create_args[@]}"
