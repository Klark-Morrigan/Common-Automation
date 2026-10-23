#!/usr/bin/env bash
# Resolves the text a value shows. Sourced, not executed: defines
# resolve_display_text.

# shellcheck source=SCRIPTDIR/../log-record-format.sh
source "${BASH_SOURCE[0]%/*}/../log-record-format.sh"

# Leaves in display_text the text a value shows: a locale tag upper-cased,
# anything else as written. A table measures this text, not the written one,
# so a column fits what it shows.
#   resolve_display_text <role> <text>
# shellcheck disable=SC2034 # display_text is the result, read by the caller
resolve_display_text() {

    if [[ "$1" == "${LOG_ROLE_LOCALE}" ]]; then

        display_text="${2^^}"
        return 0
    fi

    display_text="$2"
}
