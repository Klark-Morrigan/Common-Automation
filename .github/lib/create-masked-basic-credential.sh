#!/usr/bin/env bash
# Encodes a token as the HTTP Basic credential git sends to GitHub, masked in
# the GitHub Actions log. Sourced, not executed: defines
# create_masked_basic_credential.
#
# Actions masks a secret in its log, but not an encoding of it. Masking the
# encoding where it is made means no caller can forget to.
#
# Not readonly: a script may source this file more than once.

# shellcheck source=SCRIPTDIR/is-running-in-github-actions.sh
source "${BASH_SOURCE[0]%/*}/is-running-in-github-actions.sh"

# shellcheck source=SCRIPTDIR/print-workflow-command.sh
source "${BASH_SOURCE[0]%/*}/print-workflow-command.sh"

# The user name GitHub expects beside an installation, workflow or personal
# access token.
BASIC_CREDENTIAL_USER_NAME="x-access-token"

# Leaves in basic_credential the token's HTTP Basic credentials, in the form
# actions/checkout sends. The token reaches base64 through a pipe, never a
# command line. Under GitHub Actions it also prints the command that masks the
# credential, to stdout. Printed only there, so a local run does not write the
# credential to the terminal.
#   create_masked_basic_credential <token>
# shellcheck disable=SC2034 # basic_credential is the result, read by the caller
create_masked_basic_credential() {

    # shellcheck disable=SC2312 # the scripts sourcing this run under pipefail
    basic_credential="$(printf '%s:%s' "${BASIC_CREDENTIAL_USER_NAME}" "$1" | base64 | tr -d '\n')"

    if is_running_in_github_actions; then
        print_workflow_command "${WORKFLOW_COMMAND_ADD_MASK}" "${basic_credential}"
    fi
}
