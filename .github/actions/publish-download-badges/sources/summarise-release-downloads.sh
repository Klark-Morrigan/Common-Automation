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
#   GH_TOKEN           optional token gh authenticates with. Cleared once
#                      read and handed to gh alone; unset, gh's own login
#                      answers.
#   RETRY_*            optional retry tuning, read by retry.sh's
#                      retry_command. Default classifiers:
#                      RETRY_CLASSIFIER_SET_HTTP.
#
# Its jq passes live beside it, in summarise-release-downloads.jq.
#
# Prints to stdout one line per release and locale, in release-summary.sh's
# format. Releases come newest first, and one release's locales in tag order.
#
# Logs to stderr, as log records, what it reads with, each draft it skips, a
# table per release of each asset it counts or ignores, and a table of the
# summary with a total per locale. So a run's log explains every figure built
# on its output.
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
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../../.." && pwd)}"

# shellcheck source=SCRIPTDIR/../../../lib/line-endings.sh
source "${repo_root}/.github/lib/line-endings.sh"

# The roles its messages name.
# shellcheck source=SCRIPTDIR/../../../lib/log-records/log-record-format.sh
source "${repo_root}/.github/lib/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../../lib/log-records/writers/jq-log-record-args.sh
source "${repo_root}/.github/lib/log-records/writers/jq-log-record-args.sh"

# shellcheck source=SCRIPTDIR/../../../lib/log-records/writers/write-log-records.sh
source "${repo_root}/.github/lib/log-records/writers/write-log-records.sh"

# shellcheck source=SCRIPTDIR/../../../lib/retry.sh
source "${repo_root}/.github/lib/retry.sh"

# shellcheck source=SCRIPTDIR/../../../lib/run-gh-with-token.sh
source "${repo_root}/.github/lib/run-gh-with-token.sh"

# shellcheck source=SCRIPTDIR/../../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

repository="${GITHUB_REPOSITORY:-}"
asset_name_regex="${ASSET_NAME_REGEX:-}"
default_locale="${DEFAULT_LOCALE:-}"
token="${GH_TOKEN:-}"

# Read once, then cleared, so jq and the other processes this script starts do
# not inherit it. Only gh gets the token.
unset GH_TOKEN

require_value GITHUB_REPOSITORY "${repository}"
require_value ASSET_NAME_REGEX "${asset_name_regex}"

# Checked before the API call, and on its own, so a bad pattern is reported as
# itself rather than as a listing jq could not read.
if ! jq -n --arg regex "${asset_name_regex}" '"" | test($regex)' > /dev/null 2>&1; then

    exit_with_error "ASSET_NAME_REGEX '${asset_name_regex}' is not a valid regex."
fi

write_log_message \
    "${LOG_ROLE_PLAIN}" "Listing the releases of " \
    "${LOG_ROLE_ID}" "${repository}" \
    "${LOG_ROLE_PLAIN}" "."

write_log_message \
    "${LOG_ROLE_PLAIN}" "Counting the assets whose name matches '" \
    "${LOG_ROLE_ID}" "${asset_name_regex}" \
    "${LOG_ROLE_PLAIN}" "'."

release_pages_file="$(mktemp)"
trap 'rm -f "${release_pages_file}"' EXIT

RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_HTTP}}" \
    retry_or_exit_to_file "list the releases of ${repository}" "${release_pages_file}" \
    run_gh_with_token "${token}" api --paginate "repos/${repository}/releases?per_page=${RELEASES_PER_PAGE}"

# gh prints each page as its own JSON array, one after another. Gathering them
# through `inputs` lets the classifying sort see every release; gh's own --jq
# runs once per page and would sort each page on its own.
#
# This pass only reads the listing, so a failure here means the answer was not
# one.
# shellcheck disable=SC2310 # the condition is the failure check; pipefail carries jq's status
if ! classified_releases=$(jq -nc -L "${script_dir}" \
    --arg assetNameRegex "${asset_name_regex}" \
    --arg defaultLocale "${default_locale}" \
    'include "summarise-release-downloads";
     [ inputs | .[] ] | classify_releases($assetNameRegex; $defaultLocale)' \
    < "${release_pages_file}" | strip_carriage_returns); then

    exit_with_error "gh's answer for the releases of ${repository} is not a releases listing."
fi

locale_use=$(jq -r -L "${script_dir}" \
    'include "summarise-release-downloads"; report_locale_use' \
    <<< "${classified_releases}" | strip_carriage_returns)

IFS=$'\t' read -r has_localised_asset unlocalised_asset <<< "${locale_use}"

# Logged once the listing is read, so the line can say which way an
# unlocalised asset goes.
if [[ -n "${default_locale}" ]]; then

    write_log_message \
        "${LOG_ROLE_PLAIN}" "DEFAULT_LOCALE: " \
        "${LOG_ROLE_LOCALE}" "${default_locale}" \
        "${LOG_ROLE_PLAIN}" ", for a counted asset whose name holds no locale."
elif [[ "${has_localised_asset}" == "true" ]]; then

    write_log_message "${LOG_ROLE_PLAIN}" \
        "DEFAULT_LOCALE: unset, and a counted asset names a locale, so one whose name holds none fails the run."
else

    write_log_message "${LOG_ROLE_PLAIN}" \
        "DEFAULT_LOCALE: unset, and no counted asset names a locale, so each counts under no locale."
fi

# The log passes are guarded like the classify pass, so a failure names the
# stage's own step rather than ending on set -e with nothing said.
# shellcheck disable=SC2310 # the condition is the failure check; pipefail carries jq's status
if ! jq -r -L "${script_dir}" "${JQ_LOG_RECORD_ARGS[@]}" \
    'include "summarise-release-downloads"; describe_classified_releases($ARGS.named)' \
    <<< "${classified_releases}" | strip_carriage_returns >&2; then

    exit_with_error "could not log the assets of ${repository}'s releases."
fi

if [[ -n "${unlocalised_asset}" && "${has_localised_asset}" == "true" ]]; then

    exit_with_error "asset '${unlocalised_asset}' of ${repository} names no locale, other assets name one," \
        "and DEFAULT_LOCALE is not set."
fi

summary=$(jq -r -L "${script_dir}" \
    'include "summarise-release-downloads"; summarise_counted_assets' \
    <<< "${classified_releases}" | strip_carriage_returns)

if [[ -z "${summary}" ]]; then

    exit_with_error "no release of ${repository} carries an asset matching '${asset_name_regex}'."
fi

# shellcheck disable=SC2310 # the condition is the failure check; pipefail carries jq's status
if ! jq -r -L "${script_dir}" "${JQ_LOG_RECORD_ARGS[@]}" \
    'include "summarise-release-downloads"; describe_release_summary($ARGS.named)' \
    <<< "${classified_releases}" | strip_carriage_returns >&2; then

    exit_with_error "could not log the summary of ${repository}'s releases."
fi

printf '%s\n' "${summary}"
