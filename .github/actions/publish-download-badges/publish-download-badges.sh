#!/usr/bin/env bash
# Publishes a repository's download-count badges: counts the downloads once,
# renders every badge figure from that count, and publishes the figures to one
# branch as shields endpoint files.
#
# Usage: publish-download-badges.sh
#
# Inputs read from the environment:
#   BADGE_LABEL        label the badges lead with.
#   BADGE_BRANCH       branch the endpoint files are published to.
#   GITHUB_REPOSITORY, ASSET_NAME_REGEX, DEFAULT_LOCALE, GH_TOKEN, RETRY_*
#                      passed through to the stages; their headers say how
#                      each is read.
#
# Each stage is a script of its own, so bats covers each alone; this script
# only chains them. The summary runs once and every renderer reads it, so the
# API is asked once and the badges of one run cannot disagree.
#
# Each stage's log sits in an Actions log group named after the stage, so the
# run's log stays readable as stages are added. The stages log to stderr, and
# so do the group markers: one stream keeps them in order, and stdout stays
# free for the data a stage hands the next.
#
# Exits non-zero, publishing nothing, when the summary or any renderer fails,
# so the badges of one run never mix fresh and stale figures. A failure that
# gets past this, such as a renderer that exits 0 without writing its file,
# meets publish-badge-branch.sh's refusal to withdraw a published file.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# shellcheck source=../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

label="${BADGE_LABEL:-}"
branch="${BADGE_BRANCH:-}"

# Checked before the summary, so a missing input fails without an API call.
require_value BADGE_LABEL "${label}"
require_value BADGE_BRANCH "${branch}"

# Runs one stage script from this folder inside a log group named after it.
# The group is closed even when the stage fails, and the stage's status is
# returned.
#   run_stage <stage script> [arguments...]
run_stage() {

    local stage_script="$1"
    local stage_status=0

    shift

    echo "::group::${stage_script%.sh}" >&2
    "${script_dir}/${stage_script}" "$@" || stage_status=$?
    echo "::endgroup::" >&2

    return "${stage_status}"
}

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

# Kept outside the badge directory, which becomes the branch's whole content.
summary_file="${work_dir}/release-summary.tsv"
badge_dir="${work_dir}/badges"

mkdir "${badge_dir}"

run_stage summarise-release-downloads.sh > "${summary_file}"

# One line per renderer. A new figure adds its line here.
run_stage render-total-downloads.sh "${label}" "${badge_dir}" < "${summary_file}"

run_stage publish-badge-branch.sh "${badge_dir}" "${branch}"
