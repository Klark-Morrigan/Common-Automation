#!/usr/bin/env bash
# Prints how many times each release's counted assets were downloaded, one
# line per release and locale, newest release first.
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
#                      anywhere in the name, so the caller anchors it. A
#                      named group `locale` gives the asset's locale.
#   DEFAULT_LOCALE     optional locale of an asset whose name holds none.
#   GH_TOKEN           token gh authenticates with (consumed by gh, not read
#                      here).
#   RETRY_*            optional retry tuning, read by retry.sh's
#                      retry_command. Default classifiers:
#                      RETRY_CLASSIFIER_SET_HTTP.
#
# Prints to stdout, tab-separated, one line per release and locale:
#   <tag>  <published_at>  <locale>  <download count>
# Releases come newest first, and one release's locales in tag order.
#
# Logs to stderr what it reads with, each draft it skips, and each asset it
# counts or ignores, so a run's log explains every figure built on its output.
#
# Drafts are skipped: the run's token can see them, and a draft has no
# downloads to report. A release with no counted asset is left out.
#
# The locale is never guessed. A project that shipped unlocalised builds
# states which locale they were through DEFAULT_LOCALE.
#
# Exits non-zero, printing nothing to stdout, when the lookup fails, its
# answer is not a releases listing, a counted asset has no locale, or no
# release carries a counted asset. A caller publishing from this output then
# keeps its last good figures rather than publishing zeroes.

set -euo pipefail

readonly SCRIPT_NAME="summarise-release-downloads"

# The API's page ceiling. --paginate fetches every page either way, so this
# only cuts the number of calls a long release history costs.
readonly RELEASES_PER_PAGE=100

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"
# shellcheck source=../../lib/line-endings.sh
source "${repo_root}/.github/lib/line-endings.sh"
# shellcheck source=../../lib/retry.sh
source "${repo_root}/.github/lib/retry.sh"

repository="${GITHUB_REPOSITORY:?${SCRIPT_NAME}: GITHUB_REPOSITORY is required}"
asset_name_regex="${ASSET_NAME_REGEX:?${SCRIPT_NAME}: ASSET_NAME_REGEX is required}"
default_locale="${DEFAULT_LOCALE:-}"

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

echo "Listing the releases of ${repository}." >&2
echo "Counting the assets whose name matches '${asset_name_regex}'." >&2

if [[ -n "${default_locale}" ]]; then
    echo "DEFAULT_LOCALE: ${default_locale}, for a counted asset whose name holds no locale." >&2
else
    echo "DEFAULT_LOCALE: unset, so a counted asset whose name holds no locale fails the run." >&2
fi

release_pages_file="$(mktemp)"
trap 'rm -f "${release_pages_file}"' EXIT

RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_HTTP}}" \
    retry_or_exit "list the releases of ${repository}" fetch_release_pages "${release_pages_file}"

# gh prints each page as its own JSON array, one after another. Gathering them
# through `inputs` lets the sort below see every release; gh's own --jq runs
# once per page and would sort each page on its own.
#
# GitHub does not document the order this listing comes back in, hence the
# sort. published_at is ISO 8601 in UTC, so it sorts as text. The tag breaks a
# tie, so equal listings give equal output. A draft has no publish time, so
# drafts sort last.
#
# Every asset is kept, counted or not, so the log can name what was ignored.
# capture() yields nothing for a name the regex does not match. Its locale is
# null when the group took no part in the match, absent when the regex has no
# such group, and empty when it matched nothing; all three fall back to the
# default.
#
# This pass only reads the listing, so a failure here means the answer was not
# one.
if ! classified_releases=$(jq -nc \
    --arg assetNameRegex "${asset_name_regex}" \
    --arg defaultLocale "${default_locale}" \
    '[ inputs | .[] ]
     | sort_by(.published_at, .tag_name) | reverse
     | map(
         { tag: .tag_name, publishedAt: .published_at, draft,
           assets: [ .assets[]
                     | ([ .name | capture($assetNameRegex) ] | first) as $groups
                     | ($groups.locale // "") as $nameLocale
                     | { name, count: .download_count, counted: ($groups != null) }
                       + if $groups == null then { locale: null, localeOrigin: null }
                         elif $nameLocale != "" then { locale: $nameLocale, localeOrigin: "its name" }
                         elif $defaultLocale != "" then { locale: $defaultLocale, localeOrigin: "DEFAULT_LOCALE" }
                         else { locale: null, localeOrigin: null }
                         end ] })' \
    < "${release_pages_file}" | strip_carriage_returns); then

    echo "::error::${SCRIPT_NAME}: gh's answer for the releases of ${repository} is not a releases listing." >&2
    exit 1
fi

jq -r \
    '.[]
     | if .draft then
         "Skipped draft \(.tag): a draft has no downloads to report."
       else
         "Release \(.tag), published \(.publishedAt):",
         (.assets[]
          | if .counted | not then
              "  ignored \(.name): its name does not match."
            elif .locale == null then
              "  counted \(.name): \(.count) downloads, no locale."
            else
              "  counted \(.name): \(.count) downloads, locale \(.locale) from \(.localeOrigin)."
            end)
       end' \
    <<< "${classified_releases}" | strip_carriage_returns >&2

unlocalised_asset=$(jq -r \
    'first(.[] | select(.draft | not) | .assets[] | select(.counted and .locale == null) | .name) // empty' \
    <<< "${classified_releases}" | strip_carriage_returns)

if [[ -n "${unlocalised_asset}" ]]; then

    echo "::error::${SCRIPT_NAME}: asset '${unlocalised_asset}' of ${repository} names no locale," \
        "and DEFAULT_LOCALE is not set." >&2
    exit 1
fi

# group_by sorts by its key, which puts one release's locales in tag order.
summary=$(jq -r \
    '.[]
     | select(.draft | not)
     | . as $release
     | [ .assets[] | select(.counted) ]
     | group_by(.locale)[]
     | [ $release.tag, $release.publishedAt, .[0].locale, (map(.count) | add) ]
     | @tsv' \
    <<< "${classified_releases}" | strip_carriage_returns)

if [[ -z "${summary}" ]]; then

    echo "::error::${SCRIPT_NAME}: no release of ${repository} carries an asset matching '${asset_name_regex}'." >&2
    exit 1
fi

summary_line_count="$(grep -c '' <<< "${summary}")"

echo "Summarised ${summary_line_count} release and locale line(s)." >&2

printf '%s\n' "${summary}"
