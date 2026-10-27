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
# Logs to stderr, as log records, a table of every source line: its source,
# the release and locale it went to, its count, and whether it joined a line
# or created one.
#
# Exits non-zero, printing nothing to stdout, when the summary or a source
# line is malformed, a source file cannot be read, or a version matches no
# release. A version with no release is a typo on that host, and dropping or
# guessing would hide it.

set -euo pipefail

readonly LINE_JOINED="joined"
readonly LINE_CREATED="created"

# Locales compare byte by byte, as jq ordered the summary's lines.
export LC_ALL=C

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

# shellcheck source=SCRIPTDIR/release-summary.sh
source "${script_dir}/release-summary.sh"

# shellcheck source=SCRIPTDIR/source-summary.sh
source "${script_dir}/source-summary.sh"

if (( $# % 2 != 0 )); then

    exit_with_error "sources come as <source name> <file> pairs, but an odd number of arguments was given."
fi

source_count=$(( $# / 2 ))

read_release_summary

# The tags in summary order, each release's line indexes in line order keyed
# by tag, and each line's index keyed by its tag and locale. A tab joins the
# key, since neither field can hold one.
release_tags=()
declare -A line_indexes_by_tag=()
declare -A line_index_by_tag_and_locale=()

for line_index in "${!RELEASE_SUMMARY_TAGS[@]}"; do

    tag="${RELEASE_SUMMARY_TAGS[line_index]}"

    if [[ -z "${line_indexes_by_tag[${tag}]+set}" ]]; then

        release_tags+=("${tag}")
        line_indexes_by_tag["${tag}"]=""
    fi

    line_indexes_by_tag["${tag}"]+=" ${line_index}"
    line_index_by_tag_and_locale["${tag}"$'\t'"${RELEASE_SUMMARY_LOCALES[line_index]}"]="${line_index}"
done

if (( source_count == 0 )); then

    write_log_message "${LOG_ROLE_PLAIN}" "No other source: the summary passes through unchanged."
else
    write_log_table Source Release Locale Downloads Line
fi

source_line_count=0

while (( $# > 0 )); do

    source_name="$1"
    source_file="$2"

    shift 2

    require_value "source name" "${source_name}"

    if [[ ! -f "${source_file}" || ! -r "${source_file}" ]]; then

        exit_with_error "${source_name}: cannot read '${source_file}'."
    fi

    # The `|| [[ -n ... ]]` keeps a last line that has no newline.
    while IFS= read -r source_line || [[ -n "${source_line}" ]]; do

        if [[ ! "${source_line}" =~ ${SOURCE_SUMMARY_LINE_REGEX} ]]; then

            exit_with_error "${source_name}: '${source_line}' is not a source summary line."
        fi

        version="${BASH_REMATCH[1]}"
        locale="${BASH_REMATCH[2]}"

        # 10# reads a leading zero as decimal; bash would take it for octal.
        download_count=$(( 10#${BASH_REMATCH[3]} ))

        if [[ -z "${line_indexes_by_tag[${version}]+set}" ]]; then

            exit_with_error "${source_name}: version ${version} matches no release."
        fi

        line_key="${version}"$'\t'"${locale}"

        if [[ -n "${line_index_by_tag_and_locale[${line_key}]+set}" ]]; then

            line_index="${line_index_by_tag_and_locale[${line_key}]}"
            RELEASE_SUMMARY_COUNTS[line_index]=$(( RELEASE_SUMMARY_COUNTS[line_index] + download_count ))
            line_change="${LINE_JOINED}"
        else

            # A release's lines share its publish time, so the new line takes
            # its first line's.
            read -r -a release_line_indexes <<< "${line_indexes_by_tag[${version}]}"

            line_index="${#RELEASE_SUMMARY_TAGS[@]}"
            RELEASE_SUMMARY_TAGS+=("${version}")
            RELEASE_SUMMARY_PUBLISHED_TIMES+=("${RELEASE_SUMMARY_PUBLISHED_TIMES[release_line_indexes[0]]}")
            RELEASE_SUMMARY_LOCALES+=("${locale}")
            RELEASE_SUMMARY_COUNTS+=("${download_count}")
            line_index_by_tag_and_locale["${line_key}"]="${line_index}"

            # Placed before the first line whose locale sorts after its own,
            # or last when none does.
            placed_line_indexes=()
            unplaced_line_index="${line_index}"

            for release_line_index in "${release_line_indexes[@]}"; do

                release_line_locale="${RELEASE_SUMMARY_LOCALES[release_line_index]}"

                if [[ -n "${unplaced_line_index}" && "${locale}" < "${release_line_locale}" ]]; then

                    placed_line_indexes+=("${unplaced_line_index}")
                    unplaced_line_index=""
                fi

                placed_line_indexes+=("${release_line_index}")
            done

            if [[ -n "${unplaced_line_index}" ]]; then
                placed_line_indexes+=("${unplaced_line_index}")
            fi

            line_indexes_by_tag["${version}"]="${placed_line_indexes[*]}"
            line_change="${LINE_CREATED}"
        fi

        write_log_row \
            "${LOG_ROLE_PLAIN}" "${source_name}" \
            "${LOG_ROLE_PLAIN}" "${version}" \
            "${LOG_ROLE_LOCALE}" "${locale}" \
            "${LOG_ROLE_COUNT}" "${download_count}" \
            "${LOG_ROLE_PLAIN}" "${line_change}"

        source_line_count=$(( source_line_count + 1 ))
    done < "${source_file}"
done

if (( source_count > 0 )); then

    write_log_table_end
    write_log_message \
        "${LOG_ROLE_PLAIN}" "Merged " \
        "${LOG_ROLE_COUNT}" "${source_line_count}" \
        "${LOG_ROLE_PLAIN}" " lines from " \
        "${LOG_ROLE_COUNT}" "${source_count}" \
        "${LOG_ROLE_PLAIN}" " sources into " \
        "${LOG_ROLE_COUNT}" "${#RELEASE_SUMMARY_TAGS[@]}" \
        "${LOG_ROLE_PLAIN}" " summary lines."
fi

# Printed only now, once every source has merged, so a failure prints nothing.
for tag in "${release_tags[@]}"; do

    read -r -a release_line_indexes <<< "${line_indexes_by_tag[${tag}]}"

    for line_index in "${release_line_indexes[@]}"; do

        printf '%s\t%s\t%s\t%s\n' \
            "${RELEASE_SUMMARY_TAGS[line_index]}" \
            "${RELEASE_SUMMARY_PUBLISHED_TIMES[line_index]}" \
            "${RELEASE_SUMMARY_LOCALES[line_index]}" \
            "${RELEASE_SUMMARY_COUNTS[line_index]}"
    done
done
