# The jq passes of summarise-release-downloads.sh, loaded with
# `include "summarise-release-downloads";` and jq's -L set to this folder.
#
# Held apart from the script so the shell side reads as the order of the
# passes, and each pass's reasoning sits beside the jq it explains.

# Classifies the releases listing: drafts split off by tag, and every asset of
# a published release marked counted or not, with its locale.
#
# GitHub does not document the order the listing comes back in, hence the
# sort. published_at is ISO 8601 in UTC, so it sorts as text. The tag breaks a
# tie, so equal listings give equal output.
#
# Drafts are kept only by tag, for the log, so no later pass has to filter
# them out again.
#
# Every asset of a published release is kept, counted or not, so the log can
# name what was ignored. capture() yields nothing for a name the regex does
# not match. Its locale is null when the group took no part in the match,
# absent when the regex has no such group, and empty when it matched nothing.
# All three fall back to the default, or to no locale when none is set. An
# asset given no locale carries no locale key.
#
# Input: an array of every release in the listing.
def classify_releases($assetNameRegex; $defaultLocale):
  sort_by(.published_at, .tag_name) | reverse
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
                          end ] } ] };

# Reports, as one tab-separated row, whether any counted asset names a locale
# and the first counted asset that has none, or an empty field. One localised
# asset is enough to show the project keeps locales, which turns an
# unlocalised one from a count under no locale into a failure.
#
# Input: classify_releases' output.
def report_locale_use:
  [ .releases[].assets[] | select(.counted) ]
  | [ any(.[]; .localeOrigin == "name"), (first(.[] | select(.locale == null) | .name) // "") ]
  | @tsv;

# Describes each release and what became of each of its assets, then each
# skipped draft, one log line each.
#
# Input: classify_releases' output.
def describe_classified_releases:
  { name: "its name", default: "DEFAULT_LOCALE" } as $localeOriginTexts
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
    (.drafts[] | "Skipped draft \(.): a draft has no downloads to report.");

# Sums each release's counted assets per locale, one summary line each, in
# release-summary.sh's format. group_by sorts by its key, which puts one
# release's locales in tag order. Assets with no locale group under null,
# which @tsv writes as an empty field.
#
# Input: classify_releases' output.
def summarise_counted_assets:
  .releases[]
  | . as $release
  | [ .assets[] | select(.counted) ]
  | group_by(.locale)[]
  | [ $release.tag, $release.publishedAt, .[0].locale, (map(.count) | add) ]
  | @tsv;
