#!/usr/bin/env bash
# The release summary's line format: what summarise-release-downloads.sh
# prints and every later stage reads. Sourced, not executed: defines
# RELEASE_SUMMARY_FIELDS and RELEASE_SUMMARY_LINE_REGEX.
#
# One tab-separated line per release and locale. Stating the format here lets
# the stages that read it, and the run page's table of it, agree without each
# restating it.
#
# Not readonly: a script may source this file more than once.

# The fields in line order, named as the run page's table heads its columns.
# The locale field is empty for a count under no locale.
# shellcheck disable=SC2034 # read by the scripts that source this file
RELEASE_SUMMARY_FIELDS=(release published locale downloads)

# A whole line, capturing the download count. The locale may be empty, from a
# project keeping no locales.
# shellcheck disable=SC2034 # read by the scripts that source this file
RELEASE_SUMMARY_LINE_REGEX=$'^[^\t]+\t[^\t]+\t[^\t]*\t([0-9]+)$'
