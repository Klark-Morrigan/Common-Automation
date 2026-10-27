# The jq passes of summarise-release-downloads.sh, loaded with
# `include "summarise-release-downloads";` and jq's -L set to this folder.
#
# Held apart from the script so the shell side reads as the order of the
# passes, and each pass's reasoning sits beside the jq it explains.
#
# The passes that log write log records, each taking $format, the record
# format jq-log-record-args.sh hands in as $ARGS.named.

include "build-log-record" { search: "./../../../lib/log-records/writers" };

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

# Describes one asset as a row of its release's asset table: Status, Asset,
# Locale, Locale origin, Downloads, Note.
#
# An ignored asset's cells are stale, bar the note saying why. Its locale
# cells stay empty: the locale comes from the pattern its name failed.
#
# Input: one asset of classify_releases' output.
def describe_asset_row($format):
  { name: "name", default: "DEFAULT_LOCALE" } as $localeOriginTexts
  | $format.LOG_ROLE_PLAIN as $plain
  | $format.LOG_ROLE_STALE as $stale
  | build_log_record($format; $format.LOG_RECORD_KIND_ROW;
      if .counted then
        [ $format.LOG_ROLE_CURRENT, "counted",
          $plain, .name,
          $format.LOG_ROLE_LOCALE, (.locale // ""),
          $plain, ($localeOriginTexts[.localeOrigin // ""] // ""),
          $format.LOG_ROLE_COUNT, .count,
          $plain, "" ]
      else
        [ $stale, "ignored",
          $stale, .name,
          $stale, "",
          $stale, "",
          $stale, .count,
          $format.LOG_ROLE_INVALID, "its name does not match" ]
      end);

# Describes one release as a heading naming it, then a table of what became
# of each of its assets.
#
# Input: one release of classify_releases' output.
def describe_release_assets($format):
  $format.LOG_ROLE_PLAIN as $plain
  | build_log_record($format; $format.LOG_RECORD_KIND_MESSAGE;
      [ $plain, "Release ", $format.LOG_ROLE_ID, .tag, $plain, ", published \(.publishedAt):" ]),
    build_log_table($format; [ "Status", "Asset", "Locale", "Locale origin", "Downloads", "Note" ]),
    (.assets[] | describe_asset_row($format)),
    build_log_record($format; $format.LOG_RECORD_KIND_END; []);

# Describes one skipped draft, by its tag.
#
# Input: one draft tag of classify_releases' output.
def describe_skipped_draft($format):
  $format.LOG_ROLE_PLAIN as $plain
  | build_log_record($format; $format.LOG_RECORD_KIND_MESSAGE;
      [ $plain, "Skipped draft ", $format.LOG_ROLE_ID, ., $plain, ": a draft has no downloads to report." ]);

# Describes each release's assets, then each skipped draft, as log records.
#
# Input: classify_releases' output.
def describe_classified_releases($format):
  (.releases[] | describe_release_assets($format)),
  (.drafts[] | describe_skipped_draft($format));

# Sums each release's counted assets per locale, one object each, holding the
# fields of a summary line. group_by sorts by its key, which puts one
# release's locales in tag order. Assets with no locale group under null.
#
# Input: classify_releases' output.
def sum_counted_assets:
  .releases[]
  | . as $release
  | [ .assets[] | select(.counted) ]
  | group_by(.locale)[]
  | { tag: $release.tag, publishedAt: $release.publishedAt, locale: .[0].locale, count: (map(.count) | add) };

# Prints sum_counted_assets as summary lines, in release-summary.sh's format.
# A null locale is written by @tsv as an empty field.
#
# Input: classify_releases' output.
def summarise_counted_assets:
  sum_counted_assets
  | [ .tag, .publishedAt, .locale, .count ]
  | @tsv;

# Describes the summary as a table of log records, one row per summary line,
# closed by one total per locale, in tag order. Assets with no locale make one
# total with an empty locale.
#
# Input: classify_releases' output.
def describe_release_summary($format):
  $format.LOG_ROLE_PLAIN as $plain
  | [ sum_counted_assets ] as $lines
  | build_log_table($format; [ "Release", "Published", "Locale", "Downloads" ]),
    ($lines[]
     | build_log_record($format; $format.LOG_RECORD_KIND_ROW;
         [ $plain, .tag,
           $plain, .publishedAt,
           $format.LOG_ROLE_LOCALE, (.locale // ""),
           $format.LOG_ROLE_COUNT, .count ])),
    ($lines
     | group_by(.locale)[]
     | build_log_record($format; $format.LOG_RECORD_KIND_TOTAL;
         [ $plain, "", $plain, "", $format.LOG_ROLE_LOCALE, (.[0].locale // ""),
           $format.LOG_ROLE_COUNT, (map(.count) | add) ])),
    build_log_record($format; $format.LOG_RECORD_KIND_END; []);
