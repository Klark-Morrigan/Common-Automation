#!/usr/bin/env bash
# Makes jq's output LF-terminated whatever jq the host has. Sourced, not
# executed: defines strip_carriage_returns.
#
# A native Windows jq, the one Git Bash finds, ends every line with CRLF. A
# script reading jq's output line by line would carry the \r into its values,
# and a file it writes would differ from one written on Linux for the same
# data. Scripts pipe jq's output through here, so the fix and its reason live
# in one place.
#
# A filter rather than a jq wrapper: shellcheck knows the `$name` in a jq
# program is jq's, not the shell's, only when the command is named jq.

# Copies stdin to stdout without its carriage returns. A caller running under
# pipefail keeps the failure of the command piped in.
#   jq ... | strip_carriage_returns
strip_carriage_returns() {

    tr -d '\r'
}
