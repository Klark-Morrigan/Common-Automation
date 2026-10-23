#!/usr/bin/env bash
# Prints a value's display text in its role's colour. Sourced, not executed:
# defines print_display_text.
#
# Colour goes through colors.sh, gated on the stdout of the script that
# sourced it.

# shellcheck source=SCRIPTDIR/../../colors.sh
source "${BASH_SOURCE[0]%/*}/../../colors.sh"

# shellcheck source=SCRIPTDIR/resolve-role-color.sh
source "${BASH_SOURCE[0]%/*}/resolve-role-color.sh"

# Prints the text with no newline. Takes the display text, already resolved,
# so a caller that measured it does not resolve it twice.
#   print_display_text <role> <display text>
print_display_text() {

    resolve_role_color "$1"

    if [[ -z "${role_color}" ]]; then

        printf '%s' "$2"
        return 0
    fi

    colorize_fd 1 "${role_color}" "$2"
}
