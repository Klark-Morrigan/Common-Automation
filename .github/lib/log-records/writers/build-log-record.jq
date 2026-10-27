# Builds one log record in jq, for a stage whose log comes from a jq pass.
# Loaded with `include "build-log-record";`.
#
# The jq side of write-log-record.sh: a pass that builds many records would
# otherwise hand each one to the shell to write, one call per record. Same
# line, same flattening, so a presenter cannot tell the two writers apart.
#
# $format is the object jq-log-record-args.sh's JQ_LOG_RECORD_ARGS builds, as
# $ARGS.named: every LOG_RECORD_* and LOG_ROLE_* constant under its own name.

# Builds a record of the given kind from a flat array of role and text pairs.
# A text may be a number. A tab or newline inside a value becomes a space, so
# no value can split the record into extra fields or lines.
# Fails when the values do not pair up.
def build_log_record($format; $kind; $pairs):
  if ($pairs | length) % 2 != 0 then
    error("build_log_record: a \($kind) record takes role and text pairs; got \($pairs | length) values.")
  else
    [ $format.LOG_RECORD_MARKER, $kind, ($pairs[] | tostring | gsub("[\t\n\r]"; " ")) ]
    | join($format.LOG_RECORD_SEPARATOR)
  end;
