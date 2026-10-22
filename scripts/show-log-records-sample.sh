#!/usr/bin/env bash
# Shows a sample log as the terminal presenter shapes it, so the shaping can
# be checked by eye in a real terminal. The bats suites prove the layout; only
# a terminal shows whether the colours read well.
#
# Writes the sample through the log-records writers, as a stage would: a
# message, a table of every role, a table of assets with an ignored row and a
# total per locale, and a line that is not a record. Pipes it through
# .github/lib/present-log-for-terminal.sh. Reads and writes nothing else.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib_dir="${script_dir}/../.github/lib"

# shellcheck source=SCRIPTDIR/_hold-window.sh
source "${script_dir}/_hold-window.sh"
trap hold_window_open EXIT

# shellcheck source=SCRIPTDIR/../.github/lib/log-records/write-log-message.sh
source "${lib_dir}/log-records/write-log-message.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/log-records/write-log-row.sh
source "${lib_dir}/log-records/write-log-row.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/log-records/write-log-table.sh
source "${lib_dir}/log-records/write-log-table.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/log-records/write-log-table-end.sh
source "${lib_dir}/log-records/write-log-table-end.sh"

# shellcheck source=SCRIPTDIR/../.github/lib/log-records/write-log-total.sh
source "${lib_dir}/log-records/write-log-total.sh"

# The records go to stderr, as a stage writes them, and only stderr reaches
# the presenter.
{
    write_log_message "" "Reading the releases of " id "Klark-Morrigan/Starsector-Mod-KMU" "" ", default locale " locale "en" "" "."
    printf 'retry: list the releases attempt 1 failed (exit 1); retrying in 2s\n' >&2

    write_log_table "" "Role" "" "Shown as"
    write_log_row "" "id" id "KMU-0.2.0-en.zip"
    write_log_row "" "count" count "120"
    write_log_row "" "current" current "counted"
    write_log_row "" "stale" stale "ARCHIVED"
    write_log_row "" "invalid" invalid "its name does not match"
    write_log_row "" "locale" locale "zh-hans"
    write_log_row "" "plain" "" "plain words"
    write_log_table_end

    write_log_table "" "Status" "" "Asset" "" "Locale" "" "Downloads" "" "Note"
    write_log_row current "counted" id "KMU-0.2.0-en.zip" locale "en" count "120" "" ""
    write_log_row current "counted" id "KMU-0.2.0-zh-hans.zip" locale "zh-hans" count "7" "" ""
    write_log_row stale "ignored" stale "KMU-en.version" "" "" stale "26686" invalid "its name does not match"
    write_log_total "" "" "" "" locale "en" count "120" "" ""
    write_log_total "" "" "" "" locale "zh-hans" count "7" "" ""
    write_log_table_end

} 2>&1 >/dev/null | "${lib_dir}/present-log-for-terminal.sh"
