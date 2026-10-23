#!/usr/bin/env bash
# Maps a role to the colour a presenter shows it in. Sourced, not executed:
# defines resolve_role_color.

# shellcheck source=SCRIPTDIR/../log-record-format.sh
source "${BASH_SOURCE[0]%/*}/../log-record-format.sh"

# Leaves in role_color the colors.sh colour a role takes, or nothing for a
# role shown in the terminal's own text colour: plain words, a locale, and a
# role this presenter does not know.
#   resolve_role_color <role>
# shellcheck disable=SC2034 # role_color is the result, read by the caller
resolve_role_color() {

    case "$1" in
        "${LOG_ROLE_ID}")      role_color="yellow" ;;
        "${LOG_ROLE_COUNT}")   role_color="green"  ;;
        "${LOG_ROLE_CURRENT}") role_color="green"  ;;
        "${LOG_ROLE_STALE}")   role_color="grey"   ;;
        "${LOG_ROLE_INVALID}") role_color="red"    ;;
        *)                     role_color=""       ;;
    esac
}
