#!/usr/bin/env bash
# How a presenter lays out a table. Sourced, not executed: defines
# TABLE_COLUMN_GAP.
#
# Not readonly: a script may source this file more than once.

# Between two columns. Measuring a table's width and padding its cells both
# count it, so it is stated once.
# shellcheck disable=SC2034 # read by the scripts that source this file
TABLE_COLUMN_GAP="  "
