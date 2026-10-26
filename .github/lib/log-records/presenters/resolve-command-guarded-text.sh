#!/usr/bin/env bash
# Keeps a value from being read as a GitHub Actions workflow command. Sourced,
# not executed: defines resolve_command_guarded_text.
#
# A value can come from outside, such as a release tag or a file name. Printed
# where the runner looks for a command, one could stop commands, mask output
# or fake an annotation. The runner reads :: at the start of a line, after any
# whitespace, and ##[ anywhere in it. A colour reset placed inside either
# marker breaks it, and shows as nothing in the log.
#
# Only the GitHub Actions presenter turns this on: no other reader runs
# workflow commands.

# shellcheck source=SCRIPTDIR/../../print-workflow-command.sh
source "${BASH_SOURCE[0]%/*}/../../print-workflow-command.sh"

# Leaves in command_guarded_text the text with every marker broken: ##[
# anywhere, and :: when the text starts with it after any whitespace. A value
# is guarded wherever it sits in its line, since a line can start with any
# value. Colours nothing, so it is placed even under NO_COLOR.
#   resolve_command_guarded_text <text>
# shellcheck disable=SC2034 # command_guarded_text is the result, read by the caller
resolve_command_guarded_text() {

    local -r guard=$'\033[0m'
    local -r marker="${WORKFLOW_COMMAND_MARKER}"
    local -r legacy_marker="${LEGACY_WORKFLOW_COMMAND_MARKER}"
    local text="$1"
    local leading_whitespace="${text%%[![:space:]]*}"
    local rest="${text#"${leading_whitespace}"}"

    # Each marker is broken after its first character.
    if [[ "${rest}" == "${marker}"* ]]; then

        text="${leading_whitespace}${marker:0:1}${guard}${rest:1}"
    fi

    command_guarded_text="${text//"${legacy_marker}"/"${legacy_marker:0:1}${guard}${legacy_marker:1}"}"
}
