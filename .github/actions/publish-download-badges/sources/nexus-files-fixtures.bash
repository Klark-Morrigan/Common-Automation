#!/usr/bin/env bash
# Shared Nexus files-answer fixtures for this action's bats suites. Sourced -
# never run - so it carries no tests itself and is skipped by the recursive
# *.bats runner.
#
# fetch-nexus-files.sh prints the answer and every later stage reads it, so
# the suites on both sides build it here, in the shape Nexus' GraphQL API
# sends.

# Emits one file object. uniqueDownloads is carried beside totalDownloads, as
# Nexus can send both, so a case can tell which one a stage reads.
#   build_mod_file <file id> <name> <version> <category> <total> <unique>
build_mod_file() {

    jq -cn --argjson fileId "$1" --arg name "$2" --arg version "$3" --arg category "$4" \
        --argjson total "$5" --argjson unique "$6" \
        '{ fileId: $fileId, name: $name, version: $version, category: $category,
           totalDownloads: $total, uniqueDownloads: $unique }'
}

# Emits a files answer listing the given file objects.
#   build_files_answer [file object...]
build_files_answer() {

    local IFS=,
    printf '{"data":{"modFiles":[%s]}}' "$*"
}
