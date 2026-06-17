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
#   colorize <name> <text...> - echo <text> wrapped in <name>'s colour, with
#                               reset appended. Unknown <name>, or colour
#                               disabled, yields the text unchanged - so
#                               captured/CI output stays plain ASCII.
#   color_enabled             - return 0 when colour is on, 1 otherwise.

# Capture the sourcing script's stdout TTY-ness once. See the header for why
# a live check inside colorize would be wrong under command substitution.
if [[ -t 1 ]]; then
    _COLOR_STDOUT_TTY=1
else
    _COLOR_STDOUT_TTY=0
fi

# Colour is off when explicitly suppressed (NO_COLOR wins over everything),
# on when explicitly forced, and otherwise tracks whether stdout was a
# terminal.
color_enabled() {
    [[ -n "${NO_COLOR:-}" ]] && return 1
    [[ -n "${FORCE_COLOR:-}" ]] && return 0
    [[ "${_COLOR_STDOUT_TTY}" == 1 ]]
}

# Map a colour name to its SGR escape. Kept as a case (not an associative
# array) so it runs on the bash 3.2 of macOS runners. Unknown name -> exit 1
# with no output, letting colorize fall back to plain text.
_color_code() {
    case "${1}" in
        reset)   printf '\033[0m'  ;;
        bold)    printf '\033[1m'  ;;
        dim)     printf '\033[2m'  ;;
        red)     printf '\033[31m' ;;
        green)   printf '\033[32m' ;;
        yellow)  printf '\033[33m' ;;
        blue)    printf '\033[34m' ;;
        magenta) printf '\033[35m' ;;
        cyan)    printf '\033[36m' ;;
        *)       return 1          ;;
    esac
}

# echo <text> wrapped in <name>'s colour, reset appended. No trailing newline
# (callers add their own). Colour disabled or an unknown name -> plain text.
colorize() {
    local name="${1:?colorize: colour name required}"
    shift
    local text="$*"
    local code reset
    if ! color_enabled || ! code="$(_color_code "${name}")"; then
        printf '%s' "${text}"
        return 0
    fi
    # Assign reset on its own line (not inline in printf) so its exit status
    # is observed rather than masked - shellcheck SC2312 under --enable=all.
    reset="$(_color_code reset)"
    printf '%s%s%s' "${code}" "${text}" "${reset}"
}
