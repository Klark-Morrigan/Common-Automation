#!/usr/bin/env bash
# Keep a Changelog parsing helpers, sourced by the create-github-release
# action (and any other release-side bash that needs the same parse) so the
# '## [X.Y.Z]' slicing lives in one tested place rather than inline in each
# caller. Lives alongside the other sourced production helpers (retry.sh,
# get-*-version.sh).
#
# Sourced, not executed: defines changelog_latest_version and
# changelog_section. Both are pure - args in, stdout out, no globals and no
# I/O beyond reading the given file.

# Echoes the most recent release version: the first '## [X.Y.Z...]' heading,
# skipping '## [Unreleased]' (no leading digit). Empty output when none
# exists. '|| true' keeps a no-match from tripping a caller's 'set -e' so the
# caller owns the empty-result handling.
#   changelog_latest_version <changelog-file>
changelog_latest_version() {
    local file="${1:?changelog_latest_version: changelog file required}"
    grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+' "${file}" \
        | sed -E 's/^## \[([^]]+)\].*/\1/' || true
}

# Echoes the body of the '## [<version>]' section: lines after the heading up
# to (but excluding) the next '## [' heading, with surrounding blank lines
# trimmed. Empty output when the section is absent. POSIX awk only (no gawk
# match() array) so it runs on the BSD awk of macOS runners too.
#   changelog_section <changelog-file> <version>
changelog_section() {
    local file="${1:?changelog_section: changelog file required}"
    local version="${2:?changelog_section: version required}"
    awk -v ver="${version}" '
        $0 ~ "^## \\[" ver "\\]" { capture = 1; next }
        capture && /^## \[/      { exit }
        capture                  { body = body $0 "\n" }
        END {
            gsub(/^[ \t\r\n]+/, "", body)
            gsub(/[ \t\r\n]+$/, "", body)
            printf "%s", body
        }
    ' "${file}"
}
