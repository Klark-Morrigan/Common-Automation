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
#   GH_TOKEN           optional token the stages that call GitHub read. Only
#                      those stages get it. Unset, gh's own login answers.
#   NEXUS_MOD_ID       optional Nexus Mods page whose files also count. Unset,
#                      Nexus is not read. Set, NEXUS_GAME_ID and
#                      NEXUS_FILE_NAME are required.
#   GITHUB_REPOSITORY, ASSET_NAME_REGEX, DEFAULT_LOCALE, NEXUS_GAME_ID,
#   NEXUS_FILE_NAME, NEXUS_LOCALE, RETRY_*, GITHUB_STEP_SUMMARY
#                      passed through to the stages; their headers say how
#                      each is read.
#
# Each stage is a script of its own, which stands alone; this script only
# chains them, and logs the inputs it reads. The stages that read a host sit
# in sources/, the ones that write a figure in renderers/, and this script's
# own functions in chain/. Each host is asked once, the merge adds every other
# source's counts to the GitHub summary, and every renderer reads that one
# merged summary, so the badges of one run cannot disagree. The merged summary
# goes to the run's page as a table, and each other source's lines as a table
# of their own, so each figure can be traced to the host that reported it.
#
# A dry run is how a change is checked against live counts before a scheduled
# run publishes it. It says so in its first and last line, so its output is
# never read as a publish. Those lines are log records shaped by the presenter
# the stages' logs go through, so they read alike.
#
# Exits non-zero, publishing nothing, when any stage before the publish fails,
# so the badges of one run never mix fresh and stale figures. A failure that
# gets past this, such as a renderer that exits 0 without writing its file,
# meets publish-badge-branch.sh's refusal to withdraw a published file.

set -euo pipefail

# The run page's table of the summary.
readonly SUMMARY_TABLE_HEADING="Release downloads"

# The name the merge cites Nexus' lines by, and the heading of their table on
# the run page.
readonly NEXUS_SOURCE_NAME="Nexus"

# The heading over the endpoint files a dry run prints.
readonly RENDERED_ENDPOINTS_HEADING="Rendered endpoint files"

readonly DRY_RUN_FIRST_LINE="Dry run: every stage reads and renders, but no table is written and nothing is published."
readonly DRY_RUN_LAST_LINE="Dry run: nothing was published."

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

lib_dir="${repo_root}/.github/lib"

# The roles its messages name.
# shellcheck source=SCRIPTDIR/../../lib/log-records/log-record-format.sh
source "${lib_dir}/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../lib/log-records/writers/write-log-message.sh
source "${lib_dir}/log-records/writers/write-log-message.sh"

# shellcheck source=SCRIPTDIR/../../lib/print-section-heading.sh
source "${lib_dir}/print-section-heading.sh"

# shellcheck source=SCRIPTDIR/../../lib/run-stage.sh
source "${lib_dir}/run-stage.sh"

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${lib_dir}/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/../../lib/write-presented-log-record.sh
source "${lib_dir}/write-presented-log-record.sh"

# shellcheck source=SCRIPTDIR/chain/add-merge-source.sh
source "${script_dir}/chain/add-merge-source.sh"

# shellcheck source=SCRIPTDIR/chain/is-dry-run.sh
source "${script_dir}/chain/is-dry-run.sh"

# shellcheck source=SCRIPTDIR/chain/write-run-page-table.sh
source "${script_dir}/chain/write-run-page-table.sh"

# shellcheck source=SCRIPTDIR/print-rendered-endpoints.sh
source "${script_dir}/print-rendered-endpoints.sh"

# shellcheck source=SCRIPTDIR/summaries/release-summary.sh
source "${script_dir}/summaries/release-summary.sh"

# Kept as a plain shell variable, so a stage gets the token only when its
# run_stage line names it with --export. A renderer, the table writer and the
# presenters never need it, and so never hold it.
export -n GH_TOKEN

label="${BADGE_LABEL:-}"
branch="${BADGE_BRANCH:-}"
nexus_mod_id="${NEXUS_MOD_ID:-}"
is_nexus_read=false

# A project not on Nexus sets no mod id.
if [[ -n "${nexus_mod_id}" ]]; then
    is_nexus_read=true
fi

# Checked before the summary, so a missing input fails without an API call.
require_value BADGE_LABEL "${label}"

# shellcheck disable=SC2310 # its status is the answer, not a failure
if ! is_dry_run; then
    require_value BADGE_BRANCH "${branch}"
fi

if [[ "${is_nexus_read}" == true ]]; then

    require_value NEXUS_GAME_ID "${NEXUS_GAME_ID:-}"
    require_value NEXUS_FILE_NAME "${NEXUS_FILE_NAME:-}"
fi

work_dir="$(mktemp -d)"

# A dry run's last line comes from the trap, so it closes the log however the
# run ended. Under GitHub Actions nothing else logs where the figures go, so
# the inputs are logged here.
# shellcheck disable=SC2310 # its status is the answer, not a failure
if is_dry_run; then

    trap 'rm -rf "${work_dir}"
        write_presented_log_record write_log_message "${LOG_ROLE_PLAIN}" "${DRY_RUN_LAST_LINE}"' EXIT
    write_presented_log_record write_log_message "${LOG_ROLE_PLAIN}" "${DRY_RUN_FIRST_LINE}"
    write_presented_log_record write_log_message \
        "${LOG_ROLE_PLAIN}" "Rendering the figures labelled " \
        "${LOG_ROLE_ID}" "${label}" \
        "${LOG_ROLE_PLAIN}" "."
else

    trap 'rm -rf "${work_dir}"' EXIT
    write_presented_log_record write_log_message \
        "${LOG_ROLE_PLAIN}" "Publishing the figures labelled " \
        "${LOG_ROLE_ID}" "${label}" \
        "${LOG_ROLE_PLAIN}" " to " \
        "${LOG_ROLE_ID}" "${branch}" \
        "${LOG_ROLE_PLAIN}" "."
fi

if [[ "${is_nexus_read}" == true ]]; then

    write_presented_log_record write_log_message \
        "${LOG_ROLE_PLAIN}" "Reading Nexus mod " \
        "${LOG_ROLE_ID}" "${nexus_mod_id}" \
        "${LOG_ROLE_PLAIN}" " as a source besides the GitHub releases."
else
    write_presented_log_record write_log_message "${LOG_ROLE_PLAIN}" "Skipping Nexus: NEXUS_MOD_ID is unset."
fi

# Kept outside the badge directory, which becomes the branch's whole content.
github_summary_file="${work_dir}/github-summary.tsv"
nexus_answer_file="${work_dir}/nexus-answer.json"
nexus_summary_file="${work_dir}/nexus-summary.tsv"
summary_file="${work_dir}/release-summary.tsv"
badge_dir="${work_dir}/badges"

mkdir "${badge_dir}"

run_stage --export GH_TOKEN "${script_dir}/sources/summarise-release-downloads.sh" > "${github_summary_file}"

# Filled by add_merge_source, one <source name> <file> pair per source.
MERGE_SOURCES=()

if [[ "${is_nexus_read}" == true ]]; then

    run_stage "${script_dir}/sources/fetch-nexus-files.sh" > "${nexus_answer_file}"
    run_stage "${script_dir}/sources/summarise-nexus-downloads.sh" < "${nexus_answer_file}" > "${nexus_summary_file}"
    add_merge_source "${NEXUS_SOURCE_NAME}" "${nexus_summary_file}"
fi

run_stage "${script_dir}/merge-release-downloads.sh" "${MERGE_SOURCES[@]}" \
    < "${github_summary_file}" > "${summary_file}"

# Written before any renderer runs, so a run that fails while rendering or
# publishing still shows on its page the counts it read.
write_run_page_table "${SUMMARY_TABLE_HEADING}" "${RELEASE_SUMMARY_FIELDS[@]}" < "${summary_file}"

# One line per renderer. A new figure adds its line here.
run_stage "${script_dir}/renderers/render-total-downloads.sh" "${label}" "${badge_dir}" < "${summary_file}"

# shellcheck disable=SC2310 # its status is the answer, not a failure
if is_dry_run; then

    print_section_heading "${RENDERED_ENDPOINTS_HEADING}" >&2
    print_rendered_endpoints "${badge_dir}"
else
    run_stage --export GH_TOKEN "${script_dir}/publish-badge-branch.sh" "${badge_dir}" "${branch}"
fi
