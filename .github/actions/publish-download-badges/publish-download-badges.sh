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
#   GITHUB_ACTIONS     set by the runner. Outside Actions, each stage's log is
#                      shaped for a terminal by the terminal presenter.
#   GITHUB_REPOSITORY, ASSET_NAME_REGEX, DEFAULT_LOCALE, GH_TOKEN, RETRY_*,
#   GITHUB_STEP_SUMMARY
#                      passed through to the stages; their headers say how
#                      each is read.
#
# Each stage is a script of its own, so bats covers each alone; this script
# only chains them. The stages that read a host sit in sources/, the ones that
# write a figure in renderers/. The summary runs once and every renderer reads it, so the
# API is asked once and the badges of one run cannot disagree. The summary
# also goes to the run's page as a table, so each figure can be traced to the
# counts it was rendered from.
#
# Each stage's log sits in an Actions log group named after the stage, so the
# run's log stays readable as stages are added. The stages log to stderr, and
# so do the group markers: one stream keeps them in order, and stdout stays
# free for the data a stage hands the next.
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

lib_dir="${repo_root}/.github/lib"

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${lib_dir}/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/release-summary.sh
source "${script_dir}/release-summary.sh"

terminal_presenter="${lib_dir}/log-records/presenters/present-log-for-terminal.sh"

label="${BADGE_LABEL:-}"
branch="${BADGE_BRANCH:-}"

is_dry_run=false
is_in_actions=false

if [[ "${BADGE_DRY_RUN:-}" == "true" ]]; then

    is_dry_run=true
fi

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then

    is_in_actions=true
fi

# Removes the working files, and closes a dry run's log with its last line,
# however the run ended.
finish_run() {

    if [[ -n "${work_dir:-}" ]]; then

        rm -rf "${work_dir}"
    fi

    if [[ "${is_dry_run}" == true ]]; then

        echo "Dry run: nothing was published." >&2
    fi
}

trap finish_run EXIT

if [[ "${is_dry_run}" == true ]]; then

    echo "Dry run: every stage reads and renders, but no table is written and nothing is published." >&2
fi

# Checked before the summary, so a missing input fails without an API call.
require_value BADGE_LABEL "${label}"

if [[ "${is_dry_run}" != true ]]; then

    require_value BADGE_BRANCH "${branch}"
fi

# Runs one stage script inside a log group named after its file. The group is
# closed even when the stage fails, and the stage's status is returned.
#   run_stage <stage script path> [arguments...]
#
# Outside Actions the stage's stderr goes through the terminal presenter. Its
# stdout leaves through fd 3, around the pipe, so the data it hands the next
# stage never reaches the presenter.
run_stage() {

    local stage_script="$1"
    local stage_file_name="${1##*/}"
    local stage_status=0

    shift

    echo "::group::${stage_file_name%.sh}" >&2

    if [[ "${is_in_actions}" == true ]]; then

        "${stage_script}" "$@" || stage_status=$?
    else

        # pipefail hands back the stage's status, since the presenter's is 0.
        { "${stage_script}" "$@" 2>&1 1>&3 3>&- | "${terminal_presenter}" >&2 3>&-; } 3>&1 \
            || stage_status=$?
    fi

    echo "::endgroup::" >&2

    return "${stage_status}"
}

# Prints each rendered endpoint file to stdout, as "<file>: <content>".
#   print_rendered_endpoints <badge directory>
print_rendered_endpoints() {

    local endpoint_file
    local endpoint

    for endpoint_file in "$1"/*; do

        # An empty directory leaves the glob unexpanded.
        if [[ ! -f "${endpoint_file}" ]]; then

            continue
        fi

        endpoint="$(< "${endpoint_file}")"
        printf '%s: %s\n' "${endpoint_file##*/}" "${endpoint}"
    done
}

work_dir="$(mktemp -d)"

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

    print_rendered_endpoints "${badge_dir}"
else

    run_stage "${script_dir}/publish-badge-branch.sh" "${badge_dir}" "${branch}"
fi
