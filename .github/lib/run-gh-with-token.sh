#!/usr/bin/env bash
# Runs one gh call that authenticates with a token. Sourced, not executed:
# defines run_gh_with_token.
#
# gh reads its token from GH_TOKEN. Set on this one gh process, the token
# reaches no other process the caller starts, which an exported GH_TOKEN would.

# Runs gh with the arguments given and GH_TOKEN set to the token, for this
# process alone. An empty token runs gh without one, so gh's own login answers,
# as on a person's machine.
#   run_gh_with_token <token> <gh argument...>
run_gh_with_token() {

    local token="$1"

    shift

    if [[ -z "${token}" ]]; then
        gh "$@"
        return
    fi

    GH_TOKEN="${token}" gh "$@"
}
