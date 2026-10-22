#!/usr/bin/env bash
# Shared ANSI colour helper for .github/lib shell scripts. Centralises the
# "colour only when it will reach a terminal" decision so callers highlight
# output through one tested place instead of re-deriving the TTY/NO_COLOR
# gate inline (and drifting on it). Sourced, not executed.
#
# colorize is meant to be used inside command substitution:
#     echo "$(colorize green "fixing +x on ${f}")"
# Inside $(...) fd 1 is a pipe, so a live `[[ -t 1 ]]` check would always
# read "not a terminal" and silently strip colour. To avoid that, whether
# the *sourcing script's* stdout is a terminal is captured ONCE here, at
# source time, and reused on every call.
#
# Env overrides (read live on each call, so a caller can flip them per run).
# NO_COLOR takes precedence: it is the user's universal opt-out and must win
# even against an explicit FORCE_COLOR.
#   NO_COLOR    (any value) - force colour off   (https://no-color.org)
#   FORCE_COLOR (any value) - force colour on, even when piped or captured
#                             (e.g. a menu runner that records the stream
#                             but still renders escapes)
#
# API:
#   colorize <name> <text...>     - echo <text> wrapped in <name>'s colour,
#                                   reset appended. Gated on stdout's TTY.
#                                   Unknown <name>, or colour disabled,
#                                   yields the text unchanged - so
#                                   captured/CI output stays plain ASCII.
#   colorize_fd <fd> <name> <txt> - as colorize, but gated on <fd>'s TTY
#                                   (1=stdout, 2=stderr). Lets a stderr
#                                   writer (e.g. a logger) tint only when
#                                   stderr itself is a terminal, so a
#                                   `cmd 2>file` capture stays plain ASCII.
#   color_enabled [fd]            - return 0 when colour is on for <fd>
#                                   (default 1=stdout, 2=stderr), else 1.

# Capture the sourcing script's stdout AND stderr TTY-ness once, at source
# time. See the header for why a live check inside colorize would be wrong
# under command substitution (fd 1 becomes a pipe). Both fds are captured
# so a stderr writer can gate on stderr's terminal-ness independently.
if [[ -t 1 ]]; then _COLOR_STDOUT_TTY=1; else _COLOR_STDOUT_TTY=0; fi
if [[ -t 2 ]]; then _COLOR_STDERR_TTY=1; else _COLOR_STDERR_TTY=0; fi

# Colour is off when explicitly suppressed (NO_COLOR wins over everything),
# on when explicitly forced, and otherwise tracks whether the requested fd
# was a terminal. $1 selects the fd: 2 = stderr, anything else (default) =
# stdout. The fd argument lets a stderr logger avoid writing escape bytes
# into a `cmd 2>file` capture while stdout is still a TTY.
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
# Actions log alike.
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

# Stdout-gated wrapper - the common case, used inside `$(colorize ...)`.
# Back-compatible shim over colorize_fd so existing callers are unchanged.
colorize() {
    colorize_fd 1 "$@"
}
