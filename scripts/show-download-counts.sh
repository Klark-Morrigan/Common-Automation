#!/usr/bin/env bash
# Shows what the publish-download-badges action would publish for a
# repository, publishing nothing: a dry run of its whole chain, with each
# stage's log shaped for a terminal. So a change to a stage can be checked
# against live counts before a scheduled run publishes it.
#
# Usage: show-download-counts.sh --repository <owner/name> --asset-name-regex <regex>
#            --label <label> [--<action input> <value>]...
#
# Every flag but --repository is one of the action's inputs, read from
# action-input-variables.sh, so a new input gains its flag with no edit here;
# action.yml says what each takes. Outside Actions no run names the
# repository, so it takes a flag of its own. The script knows nothing of any
# caller; a project's own script derives the flags.
#
# The chain runs from this checkout, which may hold changes a scheduled run,
# using the action at @master, would not. So the checkout's state is logged
# first.
#
# Needs gh on PATH, logged in with gh auth login.

set -euo pipefail

# The action's inputs a dry run has no use for: it publishes nothing, and gh
# reads with the login of whoever runs it.
readonly DRY_RUN_UNUSED_INPUTS=(branch token)

# The flags a dry run cannot do without, named here rather than left to the
# chain, which would name the variable instead of the flag.
readonly REQUIRED_FLAGS=(--repository --asset-name-regex --label)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
action_dir="${repo_root}/.github/actions/publish-download-badges"

# shellcheck source=SCRIPTDIR/_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT

# shellcheck source=SCRIPTDIR/log.sh
source "${script_dir}/log.sh"

# shellcheck source=SCRIPTDIR/../.github/actions/publish-download-badges/action-input-variables.sh
source "${action_dir}/action-input-variables.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/describe-git-checkout.sh
source "${repo_root}/.github/lib/describe-git-checkout.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/print-section-heading.sh
source "${repo_root}/.github/lib/print-section-heading.sh"

declare -A flag_variables=([--repository]=GITHUB_REPOSITORY)

for input_variable in "${ACTION_INPUT_VARIABLES[@]}"; do

    input="${input_variable%%=*}"

    if [[ " ${DRY_RUN_UNUSED_INPUTS[*]} " != *" ${input} "* ]]; then
        flag_variables["--${input}"]="${input_variable#*=}"
    fi
done

# Cleared first, so a variable left in the caller's shell cannot stand in for
# a flag that was not given.
unset "${flag_variables[@]}"

while (( $# > 0 )); do

    flag="$1"
    variable_name="${flag_variables[${flag}]:-}"

    if [[ -z "${variable_name}" ]]; then

        log_err "unknown flag '${flag}'."
        exit 2
    fi

    if (( $# < 2 )); then

        log_err "flag '${flag}' needs a value."
        exit 2
    fi

    # An empty value is kept: an empty default locale is the action's own
    # default.
    export "${variable_name}=$2"
    shift 2
done

for flag in "${REQUIRED_FLAGS[@]}"; do

    variable_name="${flag_variables[${flag}]}"

    if [[ -z "${!variable_name:-}" ]]; then

        log_err "flag '${flag}' is required."
        exit 2
    fi
done

print_section_heading "Common-Automation checkout" >&2
describe_git_checkout "${repo_root}" >&2

BADGE_DRY_RUN=true "${action_dir}/publish-download-badges.sh"
