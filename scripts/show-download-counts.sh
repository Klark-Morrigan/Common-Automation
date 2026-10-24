#!/usr/bin/env bash
# Shows what the publish-download-badges action would publish for a
# repository, publishing nothing: a dry run of its whole chain, with each
# stage's log shaped for a terminal. So a change to a stage can be checked
# against live counts before a scheduled run publishes it.
#
# Usage: show-download-counts.sh --repository <owner/name> --asset-name-regex <regex>
#            --label <label> [--default-locale <locale>]
#
# The flags are the action's inputs, named as its action.yml names them. Its
# branch and token have none: a dry run publishes nothing, and gh reads with
# the login of whoever runs it. The script knows nothing of any caller; a
# project's own script derives the flags.
#
# Needs gh on PATH, logged in with gh auth login.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
publish_script="${script_dir}/../.github/actions/publish-download-badges/publish-download-badges.sh"

# shellcheck source=SCRIPTDIR/_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT

# shellcheck source=SCRIPTDIR/log.sh
source "${script_dir}/log.sh"

while (( $# > 0 )); do

    flag="$1"

    case "${flag}" in

        --repository) variable_name=GITHUB_REPOSITORY ;;
        --asset-name-regex) variable_name=ASSET_NAME_REGEX ;;
        --default-locale) variable_name=DEFAULT_LOCALE ;;
        --label) variable_name=BADGE_LABEL ;;

        *)
            log_err "unknown flag '${flag}'."
            exit 2
            ;;
    esac

    if (( $# < 2 )); then

        log_err "flag '${flag}' needs a value."
        exit 2
    fi

    # An empty value is kept: an empty default locale is the action's own
    # default.
    export "${variable_name}=$2"
    shift 2
done

# A missing required flag is left to the chain, which names the input it
# lacks before it asks the API anything.
BADGE_DRY_RUN=true "${publish_script}"
