#!/usr/bin/env bash
# Picks the presenter that shapes log records for whoever reads the log.
# Sourced, not executed: defines resolve_log_presenter.
#
# A chain's stages and the chain's own lines must read alike, so both take
# their presenter from here.

# Leaves in log_presenter the path of the GitHub Actions presenter under GitHub
# Actions, else the terminal presenter.
#   resolve_log_presenter
# shellcheck disable=SC2034 # log_presenter is the result, read by the caller
resolve_log_presenter() {

    local presenters_dir="${BASH_SOURCE[0]%/*}/log-records/presenters"

    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        log_presenter="${presenters_dir}/present-log-for-github-actions.sh"
        return 0
    fi

    log_presenter="${presenters_dir}/present-log-for-terminal.sh"
}
