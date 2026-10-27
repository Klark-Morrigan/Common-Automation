#!/usr/bin/env bash
# Shared GitHub releases-listing fixtures for summarise-release-downloads.sh's
# bats suites. Sourced - never run - so it carries no tests itself and is
# skipped by the recursive *.bats runner.
#
# The unit and the integration suite both stub gh with a listing, in the shape
# gh prints with --paginate and no --jq: one JSON array per page, back to back.

# Emits one release object, given its tag, its publish time, and its assets as
# "<name>:<download count>" pairs. A draft is stated with "draft" in place of
# the time, because a draft carries no publish time.
#   build_release <tag> <published_at | draft> [<asset name>:<count>...]
build_release() {

    local tag="$1" published_at="$2"

    shift 2

    jq -cn --arg tag "${tag}" --arg publishedAt "${published_at}" \
        '{ tag_name: $tag,
           published_at: (if $publishedAt == "draft" then null else $publishedAt end),
           draft: ($publishedAt == "draft"),
           assets: [ $ARGS.positional[]
                     | capture("^(?<name>.*):(?<count>[0-9]+)$")
                     | { name, download_count: (.count | tonumber) } ] }' \
        --args "$@"
}

# Emits one page of the listing from the given release objects.
#   build_page [release object...]
build_page() {

    local IFS=,
    printf '[%s]' "$*"
}

# Makes the gh stub answer with the given pages, as gh prints them.
#   stub_pages <page...>
stub_pages() {

    export GH_STUB_STDOUT="$*"
}
