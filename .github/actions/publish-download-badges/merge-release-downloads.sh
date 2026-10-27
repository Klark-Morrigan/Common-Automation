#!/usr/bin/env bash
# Adds the downloads other sources report to the GitHub release summary, by
# version and locale.
#
# Usage: merge-release-downloads.sh [<source name> <file>]... < summary
#
# Reads summarise-release-downloads.sh's output on stdin, in
# release-summary.sh's format. Each <file> holds one source's lines, in
# source-summary.sh's format, such as summarise-nexus-downloads.sh prints.
# <source name> is what the log and a failure cite.
#
# GitHub is the spine: every version a figure counts is a GitHub release, and
# the order of releases and their publish times come from GitHub alone. A
# source line joins the line whose tag equals its version exactly and whose
# locale equals its own, an empty locale included. A locale the release has no
# line for gains a line of its own, placed among the release's lines by locale,
# as the summary orders them.
#
# Prints the merged summary to stdout, in release-summary.sh's format, so the
# renderers read it unchanged. With no source it is the summary as read.
#
# Logs to stderr, as log records, each source's name and a table of its lines:
# the release and locale each went to, its count, and whether it joined a line
# or created one. Then how many sources and lines it merged.
#
# Exits non-zero, printing nothing to stdout, when a source argument is
# missing or unreadable, the summary or a source line is malformed, or a
# version matches no release. The arguments are checked before the summary is
# read. A version with no release is a typo on that host, and dropping or
# guessing would hide it.

set -euo pipefail

readonly LINE_JOINED="joined"
readonly LINE_CREATED="created"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# COMMON_AUTOMATION_REPO_ROOT is authoritative when the composite exports it;
# the relative fallback resolves the same file from this script's location.
repo_root="${COMMON_AUTOMATION_REPO_ROOT:-$(cd "${script_dir}/../../.." && pwd)}"

# The roles its records name.
# shellcheck source=SCRIPTDIR/../../lib/log-records/log-record-format.sh
source "${repo_root}/.github/lib/log-records/log-record-format.sh"

# shellcheck source=SCRIPTDIR/../../lib/log-records/writers/write-log-records.sh
source "${repo_root}/.github/lib/log-records/writers/write-log-records.sh"

# shellcheck source=SCRIPTDIR/../../lib/workflow-commands.sh
source "${repo_root}/.github/lib/workflow-commands.sh"

# shellcheck source=SCRIPTDIR/summaries/read-release-summary.sh
source "${script_dir}/summaries/read-release-summary.sh"

# shellcheck source=SCRIPTDIR/summaries/read-source-summary.sh
source "${script_dir}/summaries/read-source-summary.sh"

if (( $# % 2 != 0 )); then

    exit_with_error "sources come as <source name> <file> pairs, but an odd number of arguments was given."
fi

source_names=()
source_files=()

while (( $# > 0 )); do

    require_value "source name" "$1"

    if [[ ! -f "$2" || ! -r "$2" ]]; then
        exit_with_error "$1: cannot read '$2'."
    fi

    source_names+=("$1")
    source_files+=("$2")

    shift 2
done

read_release_summary

# Each release numbered in summary order, with its publish time, and each
# line's index keyed by its tag and locale. A release's lines share one publish
# time. A tab joins the key, since neither field can hold one.
declare -A release_ordinal_by_tag=()
declare -A published_time_by_tag=()
declare -A line_index_by_tag_and_locale=()

for line_index in "${!RELEASE_SUMMARY_TAGS[@]}"; do

    tag="${RELEASE_SUMMARY_TAGS[line_index]}"

    if [[ -z "${release_ordinal_by_tag[${tag}]+set}" ]]; then
        release_ordinal_by_tag["${tag}"]="${#release_ordinal_by_tag[@]}"
        published_time_by_tag["${tag}"]="${RELEASE_SUMMARY_PUBLISHED_TIMES[line_index]}"
    fi

    line_index_by_tag_and_locale["${tag}"$'\t'"${RELEASE_SUMMARY_LOCALES[line_index]}"]="${line_index}"
done

if (( ${#source_names[@]} == 0 )); then

    write_log_message "${LOG_ROLE_PLAIN}" "No other source: the summary passes through unchanged."
fi

source_line_count=0

for source_index in "${!source_names[@]}"; do

    source_name="${source_names[source_index]}"
    source_file="${source_files[source_index]}"

    read_source_summary "${source_name}" < "${source_file}"

    # The file is not named: a caller's file is often temporary, and the name
    # is what identifies the source.
    write_log_message \
        "${LOG_ROLE_PLAIN}" "Merging " \
        "${LOG_ROLE_ID}" "${source_name}" \
        "${LOG_ROLE_PLAIN}" ":"
    write_log_table Release Locale Downloads Line

    for source_line_index in "${!SOURCE_SUMMARY_VERSIONS[@]}"; do

        version="${SOURCE_SUMMARY_VERSIONS[source_line_index]}"
        locale="${SOURCE_SUMMARY_LOCALES[source_line_index]}"
        download_count="${SOURCE_SUMMARY_COUNTS[source_line_index]}"
        line_key="${version}"$'\t'"${locale}"

        if [[ -z "${release_ordinal_by_tag[${version}]+set}" ]]; then
            exit_with_error "${source_name}: version ${version} matches no release."
        fi

        if [[ -n "${line_index_by_tag_and_locale[${line_key}]+set}" ]]; then
            line_index="${line_index_by_tag_and_locale[${line_key}]}"
            RELEASE_SUMMARY_COUNTS[line_index]=$(( RELEASE_SUMMARY_COUNTS[line_index] + download_count ))
            line_change="${LINE_JOINED}"
        else
            line_index_by_tag_and_locale["${line_key}"]="${#RELEASE_SUMMARY_TAGS[@]}"
            RELEASE_SUMMARY_TAGS+=("${version}")
            RELEASE_SUMMARY_PUBLISHED_TIMES+=("${published_time_by_tag[${version}]}")
            RELEASE_SUMMARY_LOCALES+=("${locale}")
            RELEASE_SUMMARY_COUNTS+=("${download_count}")
            line_change="${LINE_CREATED}"
        fi

        write_log_row \
            "${LOG_ROLE_PLAIN}" "${version}" \
            "${LOG_ROLE_LOCALE}" "${locale}" \
            "${LOG_ROLE_COUNT}" "${download_count}" \
            "${LOG_ROLE_PLAIN}" "${line_change}"
    done

    write_log_table_end

    source_line_count=$(( source_line_count + ${#SOURCE_SUMMARY_VERSIONS[@]} ))
done

if (( ${#source_names[@]} > 0 )); then

    write_log_message \
        "${LOG_ROLE_PLAIN}" "Sources merged: " \
        "${LOG_ROLE_COUNT}" "${#source_names[@]}" \
        "${LOG_ROLE_PLAIN}" ". Source lines: " \
        "${LOG_ROLE_COUNT}" "${source_line_count}" \
        "${LOG_ROLE_PLAIN}" ". Summary lines: " \
        "${LOG_ROLE_COUNT}" "${#RELEASE_SUMMARY_TAGS[@]}" \
        "${LOG_ROLE_PLAIN}" "."
fi

# Printed only now, once every source has merged, so a failure prints nothing.
# Each line is keyed by its release's number, then its locale byte by byte, as
# jq ordered the summary's lines. So a created line lands among its release's
# lines, and the key is cut off again.
for line_index in "${!RELEASE_SUMMARY_TAGS[@]}"; do

    tag="${RELEASE_SUMMARY_TAGS[line_index]}"
    locale="${RELEASE_SUMMARY_LOCALES[line_index]}"

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${release_ordinal_by_tag[${tag}]}" \
        "${locale}" \
        "${tag}" \
        "${RELEASE_SUMMARY_PUBLISHED_TIMES[line_index]}" \
        "${locale}" \
        "${RELEASE_SUMMARY_COUNTS[line_index]}"

done | LC_ALL=C sort --stable --field-separator=$'\t' --key=1,1n --key=2,2 | cut --fields=3-
