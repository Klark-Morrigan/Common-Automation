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
#   GITHUB_REPOSITORY, ASSET_NAME_REGEX, GH_TOKEN, RETRY_*
#                      passed through to the stages; their headers say how
#                      each is read.
#
# Each stage is a script of its own, so bats covers each alone; this script
# only chains them. The summary runs once and every renderer reads it, so the
# API is asked once and the badges of one run cannot disagree.
#
# Exits non-zero, publishing nothing, when the summary or any renderer fails,
# so the badges of one run never mix fresh and stale figures. A failure that
# gets past this, such as a renderer that exits 0 without writing its file,
# meets publish-badge-branch.sh's refusal to withdraw a published file.

set -euo pipefail

readonly SCRIPT_NAME="publish-download-badges"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Checked before the summary, so a missing input fails without an API call.
label="${BADGE_LABEL:?${SCRIPT_NAME}: BADGE_LABEL is required}"
branch="${BADGE_BRANCH:?${SCRIPT_NAME}: BADGE_BRANCH is required}"

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

# Kept outside the badge directory, which becomes the branch's whole content.
summary_file="${work_dir}/release-summary.tsv"
badge_dir="${work_dir}/badges"

mkdir "${badge_dir}"

"${script_dir}/summarise-release-downloads.sh" > "${summary_file}"

# One line per renderer. A new figure adds its line here.
"${script_dir}/render-total-downloads.sh" "${label}" "${badge_dir}" < "${summary_file}"

"${script_dir}/publish-badge-branch.sh" "${badge_dir}" "${branch}"
