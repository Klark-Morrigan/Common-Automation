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
#   RETRY_*            optional retry tuning, read by retry.sh's
#                      retry_command. Default classifiers:
#                      RETRY_CLASSIFIER_SET_HTTP.
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"
# shellcheck source=../../lib/retry.sh
source "${repo_root}/.github/lib/retry.sh"

repository="${GITHUB_REPOSITORY:?${SCRIPT_NAME}: GITHUB_REPOSITORY is required}"
asset_name_regex="${ASSET_NAME_REGEX:?${SCRIPT_NAME}: ASSET_NAME_REGEX is required}"

# Writes every page of the releases listing to the given file. Each attempt
# truncates the file, because retry_command passes output through: captured
# instead, a failed attempt's partial pages would sit beside the full listing
# and be counted twice.
fetch_release_pages() {

    gh api --paginate "repos/${repository}/releases?per_page=${RELEASES_PER_PAGE}" > "$1"
}

# Checked before the API call, and on its own, so a bad pattern is reported as
# itself rather than as a listing jq could not read.
if ! jq -n --arg regex "${asset_name_regex}" '"" | test($regex)' > /dev/null 2>&1; then

    echo "::error::${SCRIPT_NAME}: ASSET_NAME_REGEX '${asset_name_regex}' is not a valid regex." >&2
    exit 1
fi

release_pages_file="$(mktemp)"
trap 'rm -f "${release_pages_file}"' EXIT

RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_HTTP}}" \
    retry_or_exit "list the releases of ${repository}" fetch_release_pages "${release_pages_file}"

# Without --jq, gh prints each page as its own JSON array, one after another.
# The filter gathers every page through `inputs` before sorting; run once per
# page instead, it would sort each page on its own. The sort is needed at all
# because GitHub does not document the order this listing comes back in.
# published_at is ISO 8601 in UTC, so it sorts as text.
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
    < "${release_pages_file}"); then

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
