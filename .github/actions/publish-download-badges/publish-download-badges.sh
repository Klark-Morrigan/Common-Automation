#!/usr/bin/env bash
# Publishes a repository's download-count badges: counts the downloads once,
# renders every badge figure from that count, and publishes the figures to one
# branch as shields endpoint files.
#
# Usage: publish-download-badges.sh
#
# Inputs read from the environment:
#   BADGE_LABEL        label the badges lead with.
#   BADGE_BRANCH       branch the endpoint files are published to. Not read on
#                      a dry run.
#   BADGE_DRY_RUN      optional; "true" runs every stage that reads or renders,
#                      but writes no table to the run's page and publishes
#                      nothing. Each rendered endpoint file is printed to
#                      stdout instead, as "<file>: <content>".
#   GITHUB_ACTIONS     set by the GitHub Actions runner. Decides whether each
#                      stage's log is shaped for that log or for a terminal,
#                      as run-stage.sh says.
#   GITHUB_REPOSITORY, ASSET_NAME_REGEX, DEFAULT_LOCALE, GH_TOKEN, RETRY_*,
#   GITHUB_STEP_SUMMARY
#                      passed through to the stages; their headers say how
#                      each is read.
#
# Each stage is a script of its own, so bats covers each alone; this script
# only chains them. The stages that read a host sit in sources/, the ones that
# write a figure in renderers/. The summary runs once and every renderer reads
# it, so the API is asked once and the badges of one run cannot disagree. The
# summary also goes to the run's page as a table, so each figure can be traced
# to the counts it was rendered from.
#
# A dry run is how a change is checked against live counts before a scheduled
# run publishes it. It says so in its first and last line, so its output is
# never read as a publish.
#
# Exits non-zero, publishing nothing, when any stage before the publish fails,
# so the badges of one run never mix fresh and stale figures. A failure that
# gets past this, such as a renderer that exits 0 without writing its file,
# meets publish-badge-branch.sh's refusal to withdraw a published file.

set -euo pipefail

# The run page's table of the summary.
readonly SUMMARY_TABLE_HEADING="Release downloads"

# The heading over the endpoint files a dry run prints.
readonly RENDERED_ENDPOINTS_HEADING="Rendered endpoint files"

readonly DRY_RUN_FIRST_LINE="Dry run: every stage reads and renders, but no table is written and nothing is published."
readonly DRY_RUN_LAST_LINE="Dry run: nothing was published."

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

lib_dir="${repo_root}/.github/lib"

# shellcheck source=SCRIPTDIR/../../lib/print-section-heading.sh
source "${lib_dir}/print-section-heading.sh"

# shellcheck source=SCRIPTDIR/../../lib/run-stage.sh
source "${lib_dir}/run-stage.sh"

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${lib_dir}/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/print-rendered-endpoints.sh
source "${script_dir}/print-rendered-endpoints.sh"

# shellcheck source=SCRIPTDIR/release-summary.sh
source "${script_dir}/release-summary.sh"

label="${BADGE_LABEL:-}"
branch="${BADGE_BRANCH:-}"
is_dry_run=false

if [[ "${BADGE_DRY_RUN:-}" == "true" ]]; then
    is_dry_run=true
fi

work_dir="$(mktemp -d)"

# A dry run's last line comes from the trap, so it closes the log however the
# run ended.
if [[ "${is_dry_run}" == true ]]; then

    trap 'rm -rf "${work_dir}"; echo "${DRY_RUN_LAST_LINE}" >&2' EXIT
    echo "${DRY_RUN_FIRST_LINE}" >&2
else

    trap 'rm -rf "${work_dir}"' EXIT
    require_value BADGE_BRANCH "${branch}"
fi

# Checked before the summary, so a missing input fails without an API call.
require_value BADGE_LABEL "${label}"

# Kept outside the badge directory, which becomes the branch's whole content.
summary_file="${work_dir}/release-summary.tsv"
badge_dir="${work_dir}/badges"

mkdir "${badge_dir}"

run_stage "${script_dir}/sources/summarise-release-downloads.sh" > "${summary_file}"

# Written before any renderer runs, so a run that fails while rendering or
# publishing still shows on its page the counts it read.
if [[ "${is_dry_run}" != true ]]; then

    run_stage "${lib_dir}/write-step-summary-table.sh" \
        "${SUMMARY_TABLE_HEADING}" "${RELEASE_SUMMARY_FIELDS[@]}" < "${summary_file}"
fi

# One line per renderer. A new figure adds its line here.
run_stage "${script_dir}/renderers/render-total-downloads.sh" "${label}" "${badge_dir}" < "${summary_file}"

if [[ "${is_dry_run}" == true ]]; then

    print_section_heading "${RENDERED_ENDPOINTS_HEADING}" >&2
    print_rendered_endpoints "${badge_dir}"
else
    run_stage "${script_dir}/publish-badge-branch.sh" "${badge_dir}" "${branch}"
fi
