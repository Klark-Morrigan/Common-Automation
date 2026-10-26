#!/usr/bin/env bash
# Colours text only when it will reach a terminal. Sourced, not executed:
# defines color_enabled, colorize_fd and colorize.
#
# Every script colours through this one gate, so none re-derives it and drifts.
#
# Whether stdout and stderr are terminals is read once, when this file is
# sourced. Inside $(...) stdout is a pipe, so a check made on each call would
# always strip the colour of a value printed through command substitution.
#
# Two variables override the gate, read on each call:
# - NO_COLOR, any value, turns colour off (https://no-color.org). It wins over
#   everything, being the user's own opt-out.
# - FORCE_COLOR, any value, turns colour on even when piped or captured, for a
#   reader that records the stream but renders escapes.

# Whether the sourcing script's stdout and stderr are terminals, read once.
if [[ -t 1 ]]; then _COLOR_STDOUT_TTY=1; else _COLOR_STDOUT_TTY=0; fi
if [[ -t 2 ]]; then _COLOR_STDERR_TTY=1; else _COLOR_STDERR_TTY=0; fi

# Returns 0 when colour is on for the fd: 2 for stderr, anything else for
# stdout, the default. A stderr logger passes 2, so a `cmd 2>file` capture
# gets no escapes while stdout is still a terminal.
#   color_enabled [fd]
color_enabled() {
    [[ -n "${NO_COLOR:-}" ]] && return 1
    [[ -n "${FORCE_COLOR:-}" ]] && return 0
    if [[ "${1:-1}" == 2 ]]; then
        [[ "${_COLOR_STDERR_TTY}" == 1 ]]
    else
        [[ "${_COLOR_STDOUT_TTY}" == 1 ]]
    fi
}

# Map a colour name to its SGR escape, left in _color_code_value. Kept as a
# case (not an associative array) so it runs on the bash 3.2 of macOS runners.
# Assigned rather than printed: a $(...) per value forks, which costs seconds
# for a coloured table under Git Bash. Unknown name -> return 1, letting
# colorize fall back to plain text.
#
# yellow is an exact colour: common terminal schemes draw SGR 33 as a dull
# ochre. grey stays SGR 90, which reads as grey in Windows Terminal and in the
# GitHub Actions log alike.
_resolve_color_code() {
    case "${1}" in
        reset)   _color_code_value=$'\033[0m'  ;;
        bold)    _color_code_value=$'\033[1m'  ;;
        dim)     _color_code_value=$'\033[2m'  ;;
        red)     _color_code_value=$'\033[31m' ;;
        green)   _color_code_value=$'\033[32m' ;;
        yellow)  _color_code_value=$'\033[38;2;255;230;0m' ;;
        blue)    _color_code_value=$'\033[34m' ;;
        magenta) _color_code_value=$'\033[35m' ;;
        cyan)    _color_code_value=$'\033[36m' ;;
        grey)    _color_code_value=$'\033[90m' ;;
        *)       return 1 ;;
    esac
}

# echo <text> wrapped in <name>'s colour for output on <fd>, reset appended.
# No trailing newline (callers add their own). Colour disabled for <fd> or an
# unknown name -> plain text. <fd>: 1 = stdout, 2 = stderr.
colorize_fd() {
    local fd="${1:?colorize_fd: output fd required}"
    local name="${2:?colorize_fd: colour name required}"
    shift 2
    local text="$*"
    local code
    if ! color_enabled "${fd}" || ! _resolve_color_code "${name}"; then
        printf '%s' "${text}"
        return 0
    fi
    code="${_color_code_value}"
    _resolve_color_code reset
    printf '%s%s%s' "${code}" "${text}" "${_color_code_value}"
}

# colorize_fd gated on stdout, the common case.
colorize() {
    colorize_fd 1 "$@"
}
