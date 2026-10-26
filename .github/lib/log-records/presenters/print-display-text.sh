#!/usr/bin/env bash
# Prints a value's display text in its role's colour. Sourced, not executed:
# defines print_display_text.
#
# Colour goes through colors.sh, gated on the stdout of the script that
# sourced it. When that script sets is_workflow_command_guarded to true, as
# the GitHub Actions presenter does, the text is guarded against reading as a
# workflow command first. Every value a presenter prints passes through here,
# so none can skip the guard.

# shellcheck source=SCRIPTDIR/../../colors.sh
source "${BASH_SOURCE[0]%/*}/../../colors.sh"

# shellcheck source=SCRIPTDIR/resolve-command-guarded-text.sh
source "${BASH_SOURCE[0]%/*}/resolve-command-guarded-text.sh"

# shellcheck source=SCRIPTDIR/resolve-role-color.sh
source "${BASH_SOURCE[0]%/*}/resolve-role-color.sh"

# Prints the text with no newline. Takes the display text, already resolved,
# so a caller that measured it does not resolve it again. The guard changes no
# width the caller measured, being invisible.
#   print_display_text <role> <display text>
print_display_text() {

    local text="$2"

    if [[ "${is_workflow_command_guarded:-false}" == true ]]; then

        resolve_command_guarded_text "${text}"
        text="${command_guarded_text}"
    fi

    resolve_role_color "$1"

    if [[ -z "${role_color}" ]]; then

        printf '%s' "${text}"
        return 0
    fi

    colorize_fd 1 "${role_color}" "${text}"
}
