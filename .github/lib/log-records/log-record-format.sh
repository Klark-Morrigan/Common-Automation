#!/usr/bin/env bash
# The log record's line format: what a stage writes to stderr and a presenter
# reads. Sourced, not executed: defines the LOG_RECORD_* format constants and
# the LOG_ROLE_* roles.
#
# A stage's log has two readers, a person at a terminal and the Actions log,
# and each needs it shaped differently. So a stage writes plain records and a
# presenter shapes them for one reader. Stating the format here lets the
# writers and the presenters agree without each restating it.
#
# A record is one line: the marker, then the kind, then the record's role and
# text pairs, every field separated by a tab:
#
#   #log<TAB>row<TAB>id<TAB>KMU-0.2.0-en.zip<TAB>count<TAB>120
#
# A message's pairs make one run of text. A table's, row's and total's pairs
# are one cell each. An end record has no pairs.
#
# Not readonly: a script may source this file more than once.

# Starts every record, so a presenter tells records from the other lines a
# stage's stderr carries, such as curl's errors.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_MARKER="#log"

# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_SEPARATOR=$'\t'

# Where a record's pairs start once it is split at the separator: after the
# marker and the kind.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_FIRST_PAIR_INDEX=2

# A line of text.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_KIND_MESSAGE="message"

# Opens a table and names its columns.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_KIND_TABLE="table"

# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_KIND_ROW="row"

# A row that sums a column, shown under a rule after the other rows.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_KIND_TOTAL="total"

# Closes the open table.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_KIND_END="end"

# A failure, which the Actions presenter turns into an error annotation.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_KIND_ERROR="error"

# A run's outcome, which the Actions presenter turns into a notice annotation.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_RECORD_KIND_NOTICE="notice"

# The roles. A role says what a value is, never how it looks, so each
# presenter decides that alone.

# Plain words.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_ROLE_PLAIN=""

# IDs and names: games, mods, files.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_ROLE_ID="id"

# Counts, the digits only.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_ROLE_COUNT="count"

# A value in effect, such as counted.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_ROLE_CURRENT="current"

# A value out of date, and every cell of an ignored row but its note.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_ROLE_STALE="stale"

# Why something was rejected.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_ROLE_INVALID="invalid"

# A locale tag.
# shellcheck disable=SC2034 # read by the scripts that source this file
LOG_ROLE_LOCALE="locale"
