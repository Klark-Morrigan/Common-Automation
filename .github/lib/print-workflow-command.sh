#!/usr/bin/env bash
# Prints a GitHub Actions workflow command, its text escaped. Sourced, not
# executed: defines print_workflow_command and the WORKFLOW_COMMAND_* names.
#
# The runner reads a line starting with ::name:: as a command and decodes %25,
# %0D and %0A in its text. Escaping those characters here keeps a value that
# holds them from being decoded into something else, and keeps the format in
# one place.
#
# Not readonly: a script may source this file more than once.

# Starts a command, and closes its name. The runner skips a line's leading
# whitespace before looking for it.
WORKFLOW_COMMAND_MARKER="::"

# Starts a command in the runner's older format, which it still reads, found
# anywhere in a line rather than only at its start.
# shellcheck disable=SC2034 # read by the scripts that source this file
LEGACY_WORKFLOW_COMMAND_MARKER="##["

# shellcheck disable=SC2034 # read by the scripts that source this file
WORKFLOW_COMMAND_ERROR="error"

# shellcheck disable=SC2034 # read by the scripts that source this file
WORKFLOW_COMMAND_NOTICE="notice"

# Opens a collapsible group in the step log, named by its text.
# shellcheck disable=SC2034 # read by the scripts that source this file
WORKFLOW_COMMAND_GROUP="group"

# Closes the open group; takes no text.
# shellcheck disable=SC2034 # read by the scripts that source this file
WORKFLOW_COMMAND_END_GROUP="endgroup"

# Hides its text wherever the log would show it.
# shellcheck disable=SC2034 # read by the scripts that source this file
WORKFLOW_COMMAND_ADD_MASK="add-mask"

# Prints the command to stdout; a caller writing to stderr redirects it.
#   print_workflow_command <command name> [text]
print_workflow_command() {

    local text="${2:-}"

    text="${text//%/%25}"
    text="${text//$'\r'/%0D}"
    text="${text//$'\n'/%0A}"

    printf '%s%s%s%s\n' "${WORKFLOW_COMMAND_MARKER}" "$1" "${WORKFLOW_COMMAND_MARKER}" "${text}"
}
