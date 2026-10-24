#!/usr/bin/env bash
# Prints a section heading, so every script splits its output into sections
# the same way. Sourced, not executed: defines print_section_heading.

# Prints "=== <title> ===" to stdout. A caller logging to stderr redirects it
# there.
#   print_section_heading <title...>
print_section_heading() {

    printf '=== %s ===\n' "$*"
}
