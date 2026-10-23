#!/usr/bin/env bash
# Shows a sample log as the terminal presenter shapes it, so the shaping can
# be checked by eye in a real terminal. The bats suites prove the layout; only
# a terminal shows whether the colours read well.
#
# Writes the sample through the log-records writers, as a stage would: a
# message, a table of every role, a table of assets with an ignored row and a
# total per locale, and a line that is not a record. Pipes it through the
# terminal presenter. Reads and writes nothing else.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_records_dir="${script_dir}/../.github/lib/log-records"

# shellcheck source=SCRIPTDIR/_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT

# The roles the sample names.
# shellcheck source=SCRIPTDIR/../.github/lib/log-records/log-record-format.sh
source "${log_records_dir}/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/log-records/writers/write-log-records.sh
source "${log_records_dir}/writers/write-log-records.sh"

# The records go to stderr, as a stage writes them, and only stderr reaches
# the presenter.
{
    write_log_message \
        "${LOG_ROLE_PLAIN}" "Reading the releases of " \
        "${LOG_ROLE_ID}" "Klark-Morrigan/Starsector-Mod-KMU" \
        "${LOG_ROLE_PLAIN}" ", default locale " \
        "${LOG_ROLE_LOCALE}" "en" \
        "${LOG_ROLE_PLAIN}" "."
    printf 'retry: list the releases attempt 1 failed (exit 1); retrying in 2s\n' >&2

    write_log_table "Role" "Shown as"
    write_log_row "${LOG_ROLE_PLAIN}" "id" "${LOG_ROLE_ID}" "KMU-0.2.0-en.zip"
    write_log_row "${LOG_ROLE_PLAIN}" "count" "${LOG_ROLE_COUNT}" "120"
    write_log_row "${LOG_ROLE_PLAIN}" "current" "${LOG_ROLE_CURRENT}" "counted"
    write_log_row "${LOG_ROLE_PLAIN}" "stale" "${LOG_ROLE_STALE}" "ARCHIVED"
    write_log_row "${LOG_ROLE_PLAIN}" "invalid" "${LOG_ROLE_INVALID}" "its name does not match"
    write_log_row "${LOG_ROLE_PLAIN}" "locale" "${LOG_ROLE_LOCALE}" "zh-hans"
    write_log_row "${LOG_ROLE_PLAIN}" "plain" "${LOG_ROLE_PLAIN}" "plain words"
    write_log_table_end

    write_log_table "Status" "Asset" "Locale" "Downloads" "Note"
    write_log_row \
        "${LOG_ROLE_CURRENT}" "counted" \
        "${LOG_ROLE_ID}" "KMU-0.2.0-en.zip" \
        "${LOG_ROLE_LOCALE}" "en" \
        "${LOG_ROLE_COUNT}" "120" \
        "${LOG_ROLE_PLAIN}" ""
    write_log_row \
        "${LOG_ROLE_CURRENT}" "counted" \
        "${LOG_ROLE_ID}" "KMU-0.2.0-zh-hans.zip" \
        "${LOG_ROLE_LOCALE}" "zh-hans" \
        "${LOG_ROLE_COUNT}" "7" \
        "${LOG_ROLE_PLAIN}" ""
    write_log_row \
        "${LOG_ROLE_STALE}" "ignored" \
        "${LOG_ROLE_STALE}" "KMU-en.version" \
        "${LOG_ROLE_PLAIN}" "" \
        "${LOG_ROLE_STALE}" "26686" \
        "${LOG_ROLE_INVALID}" "its name does not match"
    write_log_total \
        "${LOG_ROLE_PLAIN}" "" \
        "${LOG_ROLE_PLAIN}" "" \
        "${LOG_ROLE_LOCALE}" "en" \
        "${LOG_ROLE_COUNT}" "120" \
        "${LOG_ROLE_PLAIN}" ""
    write_log_total \
        "${LOG_ROLE_PLAIN}" "" \
        "${LOG_ROLE_PLAIN}" "" \
        "${LOG_ROLE_LOCALE}" "zh-hans" \
        "${LOG_ROLE_COUNT}" "7" \
        "${LOG_ROLE_PLAIN}" ""
    write_log_table_end

} 2>&1 >/dev/null | "${log_records_dir}/presenters/present-log-for-terminal.sh"
