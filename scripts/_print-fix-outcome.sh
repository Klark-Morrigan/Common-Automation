#!/usr/bin/env bash
#
# Prints how a repo-wide fix went:
# what it changed and how to review that,
# or that nothing needed it.
#
# Sourced, not executed:
# defines print_fix_outcome.
#
# Shared by the manual fix runners, so they report alike.

# shellcheck source=SCRIPTDIR/../.github/lib/colors.sh
source "${BASH_SOURCE[0]%/*}/../.github/lib/colors.sh"

# print_fix_outcome <fix output> <review command> <clean message>
print_fix_outcome() {

    local fix_output="$1"
    local review_command="$2"
    local clean_message="$3"

    if [[ -n "${fix_output}" ]]; then
        echo "${fix_output}"
        echo "Done. Review the changes with: ${review_command}"
    else
        colorize green "${clean_message}"
        echo
    fi
}
