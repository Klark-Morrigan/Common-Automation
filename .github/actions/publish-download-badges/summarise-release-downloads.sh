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
#                      Unset, such an asset counts under no locale, unless
#                      another counted asset names one.
#   GH_TOKEN          token gh authenticates with (consumed by gh, not read
#                      here).
#   RETRY_*            optional retry tuning, read by retry.sh's
#                      retry_command. Default classifiers:
#                      RETRY_CLASSIFIER_SET_HTTP.
#
# Prints to stdout, tab-separated, one line per release and locale:
#   <tag>  <published_at>  <locale>  <download count>
# Releases come newest first, and one release's locales in tag order. The
# locale field is empty for assets counted under no locale.
#
# Logs to stderr what it reads with, each draft it skips, and each asset it
# counts or ignores, so a run's log explains every figure built on its output.
#
# Drafts are skipped: the run's token can see them, and a draft has no
# downloads to report. A release with no counted asset is left out.
#
# The locale is never guessed. A project keeping no locales has nothing to
# scope a count to, so its counts carry none: one line per release. A project
# whose assets name a locale has locales, so its unlocalised builds belong to
# one it has to state through DEFAULT_LOCALE.
#
# Exits non-zero, printing nothing to stdout, when the lookup fails, its
# answer is not a releases listing, an unlocalised asset meets a localised one
# with no DEFAULT_LOCALE set, or no release carries a counted asset. A caller
# publishing from this output then keeps its last good figures rather than
# publishing zeroes.

set -euo pipefail

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

# shellcheck source=../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

repository="${GITHUB_REPOSITORY:-}"
asset_name_regex="${ASSET_NAME_REGEX:-}"
default_locale="${DEFAULT_LOCALE:-}"

require_value GITHUB_REPOSITORY "${repository}"
require_value ASSET_NAME_REGEX "${asset_name_regex}"

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

    exit_with_error "ASSET_NAME_REGEX '${asset_name_regex}' is not a valid regex."
fi

echo "Listing the releases of ${repository}." >&2
echo "Counting the assets whose name matches '${asset_name_regex}'." >&2

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
# tie, so equal listings give equal output.
#
# Drafts are split off here, kept only by tag for the log, so no later pass
# has to filter them out again.
#
# Every asset of a published release is kept, counted or not, so the log can
# name what was ignored. capture() yields nothing for a name the regex does
# not match. Its locale is null when the group took no part in the match,
# absent when the regex has no such group, and empty when it matched nothing.
# All three fall back to the default, or to no locale when none is set. An
# asset given no locale carries no locale key.
#
# This pass only reads the listing, so a failure here means the answer was not
# one.
if ! classified_releases=$(jq -nc \
    --arg assetNameRegex "${asset_name_regex}" \
    --arg defaultLocale "${default_locale}" \
    '[ inputs | .[] ]
     | sort_by(.published_at, .tag_name) | reverse
     | { drafts: [ .[] | select(.draft) | .tag_name ],
         releases: [ .[] | select(.draft | not)
           | { tag: .tag_name, publishedAt: .published_at,
               assets: [ .assets[]
                         | ([ .name | capture($assetNameRegex) ] | first) as $groups
                         | { name, count: .download_count, counted: ($groups != null) }
                           + if $groups == null then {}
                             elif ($groups.locale // "") != "" then { locale: $groups.locale, localeOrigin: "name" }
                             elif $defaultLocale != "" then { locale: $defaultLocale, localeOrigin: "default" }
                             else {}
                             end ] } ] }' \
    < "${release_pages_file}" | strip_carriage_returns); then

    exit_with_error "gh's answer for the releases of ${repository} is not a releases listing."
fi

# Whether any counted asset names a locale, and the first that has none. One
# localised asset is enough to show the project keeps locales, which turns an
# unlocalised one from a count under no locale into a failure.
locale_check=$(jq -r \
    '[ .releases[].assets[] | select(.counted) ]
     | [ any(.[]; .localeOrigin == "name"), (first(.[] | select(.locale == null) | .name) // "") ]
     | @tsv' \
    <<< "${classified_releases}" | strip_carriage_returns)

IFS=$'\t' read -r has_localised_asset unlocalised_asset <<< "${locale_check}"

# Logged once the listing is read, so the line can say which way an
# unlocalised asset goes.
if [[ -n "${default_locale}" ]]; then

    echo "DEFAULT_LOCALE: ${default_locale}, for a counted asset whose name holds no locale." >&2
elif [[ "${has_localised_asset}" == "true" ]]; then

    echo "DEFAULT_LOCALE: unset, and a counted asset names a locale, so one whose name holds none fails the run." >&2
else

    echo "DEFAULT_LOCALE: unset, and no counted asset names a locale, so each counts under no locale." >&2
fi

jq -r \
    '{ name: "its name", default: "DEFAULT_LOCALE" } as $localeOriginTexts
     | (.releases[]
        | "Release \(.tag), published \(.publishedAt):",
          (.assets[]
           | if .counted | not then
               "  ignored \(.name): its name does not match."
             elif .locale == null then
               "  counted \(.name): \(.count) downloads, no locale."
             else
               "  counted \(.name): \(.count) downloads, locale \(.locale) from \($localeOriginTexts[.localeOrigin])."
             end)),
       (.drafts[] | "Skipped draft \(.): a draft has no downloads to report.")' \
    <<< "${classified_releases}" | strip_carriage_returns >&2

if [[ -n "${unlocalised_asset}" && "${has_localised_asset}" == "true" ]]; then

    exit_with_error "asset '${unlocalised_asset}' of ${repository} names no locale, other assets name one," \
        "and DEFAULT_LOCALE is not set."
fi

# group_by sorts by its key, which puts one release's locales in tag order.
# Assets with no locale group under null, which @tsv writes as an empty field.
summary=$(jq -r \
    '.releases[]
     | . as $release
     | [ .assets[] | select(.counted) ]
     | group_by(.locale)[]
     | [ $release.tag, $release.publishedAt, .[0].locale, (map(.count) | add) ]
     | @tsv' \
    <<< "${classified_releases}" | strip_carriage_returns)

if [[ -z "${summary}" ]]; then

    exit_with_error "no release of ${repository} carries an asset matching '${asset_name_regex}'."
fi

summary_line_count="$(grep -c '' <<< "${summary}")"

echo "Summarised ${summary_line_count} lines, one per release and locale." >&2
printf '%s\n' "${summary}"
