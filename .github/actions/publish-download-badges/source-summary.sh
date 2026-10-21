#!/usr/bin/env bash
# The source summary's line format: what a download source besides the GitHub
# releases prints, such as summarise-nexus-downloads.sh. Sourced, not
# executed: defines SOURCE_SUMMARY_FIELDS and SOURCE_SUMMARY_LINE_REGEX.
#
# One tab-separated line per version and locale. A source knows no publish
# time, so a line names its version alone, and the release it counts towards
# is the one whose tag equals that version. Stating the format here lets the
# sources, the stages that read them and the run page's tables of them agree
# without each restating it.
#
# Not readonly: a script may source this file more than once.

# The fields in line order, named as the run page's table heads its columns.
# The locale field is empty for a count under no locale.
# shellcheck disable=SC2034 # read by the scripts that source this file
SOURCE_SUMMARY_FIELDS=(version locale downloads)

# A whole line, capturing the version, the locale and the download count. The
# locale may be empty, from a project keeping no locales.
# shellcheck disable=SC2034 # read by the scripts that source this file
SOURCE_SUMMARY_LINE_REGEX=$'^([^\t]+)\t([^\t]*)\t([0-9]+)$'
