#!/usr/bin/env bash
# Runs one git call that sends a token to a remote. Sourced, not executed:
# defines run_git_with_token.
#
# The token travels as an HTTP header in git's environment config, set on this
# one git process alone. Never on a command line, which every user on the
# runner can read from the process list. Never exported, which would hand it to
# every process the caller starts. Never in a config file, which would leave it
# on disk.

# Runs git with the arguments given, sending the credential to the remote URL
# alone. The count replaces any environment config the caller set, which this
# call has no use for. Emptying credential.helper keeps a helper on the runner
# from answering a rejected token with a stored credential of its own, or from
# prompting.
#   run_git_with_token <remote url> <basic credential> <git argument...>
run_git_with_token() {

    local remote_url="$1"
    local basic_credential="$2"

    shift 2

    GIT_CONFIG_COUNT=2 \
    GIT_CONFIG_KEY_0="http.${remote_url}.extraheader" \
    GIT_CONFIG_VALUE_0="AUTHORIZATION: basic ${basic_credential}" \
    GIT_CONFIG_KEY_1="credential.helper" \
    GIT_CONFIG_VALUE_1="" \
        git "$@"
}
