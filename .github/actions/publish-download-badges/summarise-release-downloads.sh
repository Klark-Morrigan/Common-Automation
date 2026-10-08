#!/usr/bin/env bash
# Prints how many times each release's counted assets were downloaded, one
# release per line, newest first.
#
# Shields' GitHub downloads badge sums every asset of a release, or exactly
# one asset name. A repository whose releases also carry files that clients
# poll - update manifests, checksums - needs a count of only the files people
# download. That takes the asset list, so this is the one place that talks to
# the API; every badge renderer reads its output rather than asking again.
#
# Inputs are read from the environment:
#   GITHUB_REPOSITORY  owner/name of the repository whose releases are summed.
#   ASSET_NAME_REGEX   which assets count, as a regex over the whole asset
#                      name in jq's (Oniguruma) syntax. jq's test() matches
#                      anywhere in the name, so the caller anchors it.
#   GH_TOKEN           token gh authenticates with (consumed by gh, not read
#                      here).
#
# Prints to stdout, tab-separated, one line per release:
#   <tag>  <published_at>  <download count>
#
# Drafts are skipped: the run's token can see them, and a draft has no
# downloads to report. A release with no counted asset is left out.
#
# Exits non-zero, printing nothing to stdout, when the lookup fails, its
# answer is not a releases listing, or no release carries a counted asset. A
# caller publishing from this output then keeps its last good figures rather
# than publishing zeroes.

set -euo pipefail

readonly SCRIPT_NAME="summarise-release-downloads"

# The API's page ceiling. --paginate fetches every page either way, so this
# only cuts the number of calls a long release history costs.
readonly RELEASES_PER_PAGE=100

repository="${GITHUB_REPOSITORY:?${SCRIPT_NAME}: GITHUB_REPOSITORY is required}"
asset_name_regex="${ASSET_NAME_REGEX:?${SCRIPT_NAME}: ASSET_NAME_REGEX is required}"

# Checked before the API call, and on its own, so a bad pattern is reported as
# itself rather than as a listing jq could not read.
if ! jq -n --arg regex "${asset_name_regex}" '"" | test($regex)' > /dev/null 2>&1; then

    echo "::error::${SCRIPT_NAME}: ASSET_NAME_REGEX '${asset_name_regex}' is not a valid regex." >&2
    exit 1
fi

# Without --jq, gh prints each page as its own JSON array, one after another.
# The filter below gathers every page through `inputs` before sorting; run
# once per page instead, it would sort each page on its own. A failure is gh's
# own message on stderr; the line here says which lookup it belongs to.
if ! release_pages=$(gh api --paginate "repos/${repository}/releases?per_page=${RELEASES_PER_PAGE}"); then

    echo "::error::${SCRIPT_NAME}: could not list the releases of ${repository}." >&2
    exit 1
fi

# GitHub does not document the order this listing comes back in, so it is
# sorted here. published_at is ISO 8601 in UTC, so it sorts as text.
if ! summary=$(jq -nr \
    --arg assetNameRegex "${asset_name_regex}" \
    '[ inputs
       | .[]
       | select(.draft | not)
       | { tag: .tag_name,
           publishedAt: .published_at,
           counted: [ .assets[] | select(.name | test($assetNameRegex)) ] }
       | select(.counted | length > 0) ]
     | sort_by(.publishedAt) | reverse
     | .[]
     | [.tag, .publishedAt, (.counted | map(.download_count) | add)]
     | @tsv' \
    <<< "${release_pages}"); then

    echo "::error::${SCRIPT_NAME}: gh's answer for the releases of ${repository} is not a releases listing." >&2
    exit 1
fi

# A native Windows jq, the one Git Bash finds, ends every line but the last
# with CRLF. The renderers read this output line by line, so a stray \r would
# land in a count.
summary="${summary//$'\r'/}"

if [[ -z "${summary}" ]]; then

    echo "::error::${SCRIPT_NAME}: no release of ${repository} carries an asset matching '${asset_name_regex}'." >&2
    exit 1
fi

printf '%s\n' "${summary}"
