#!/usr/bin/env bats
# Unit tests for summarise-release-downloads.sh.
# Run with: bats .github/actions/publish-download-badges/summarise-release-downloads.bats
#
# The gh stub replays a releases listing built by the helpers below, in the
# shape gh prints with --paginate and no --jq: one JSON array per page, back to
# back. jq runs for real, since the filter over that listing is what is under
# test.

# shellcheck source=../../lib/test-helpers/gh-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/gh-stub.bash"

SCRIPT="${BATS_TEST_DIRNAME}/summarise-release-downloads.sh"
REPO_UNDER_TEST="Klark-Morrigan/Starsector-Mod-KMU"

# A mod's zip, unlocalised or with a locale suffix - the shape a caller of the
# action passes. Anything else on the release, polled manifests included, is
# left out of the count.
ZIP_NAME_REGEX='^KMU-[0-9]+\.[0-9]+\.[0-9]+(-.+)?\.zip$'

setup() {

    # Without jq there is no filter to run, so nothing meaningful to assert.
    command -v jq > /dev/null 2>&1 || skip "jq not available in this environment"

    install_gh_stub

    export GITHUB_REPOSITORY="${REPO_UNDER_TEST}"
    export ASSET_NAME_REGEX="${ZIP_NAME_REGEX}"
}

# Emits one release object, given its tag, its publish time, and its assets as
# "<name>:<download count>" pairs. A draft is stated with "draft" in place of
# the time, because a draft carries no publish time.
release() {

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
page() {

    local IFS=,
    printf '[%s]' "$*"
}

# Makes the stub answer with the given pages, as gh prints them.
stub_pages() {

    export GH_STUB_STDOUT="$*"
}

# Builds one expected summary line.
summary_line() {

    printf '%s\t%s\t%s' "$1" "$2" "$3"
}

@test "sums the unlocalised and every locale's zip of a release into one line" {

    stub_pages "$(page "$(release 1.2.3 2026-09-01T00:00:00Z \
        KMU-1.2.3.zip:5 KMU-1.2.3-en.zip:40 KMU-1.2.3-zh-hans.zip:15)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.3 2026-09-01T00:00:00Z 60)" ]
}

@test "leaves every version file form out of the count" {

    # The update checkers poll these on every game start, so they outnumber
    # the zips many times over - excluding them is the point of the script.
    stub_pages "$(page "$(release 1.2.3 2026-09-01T00:00:00Z \
        KMU-1.2.3-en.zip:40 kmu.version:900 kmu-en.version:800 kmu-zh-hans.version:700)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.3 2026-09-01T00:00:00Z 40)" ]
}

@test "leaves assets the regex does not match out of the count" {

    stub_pages "$(page "$(release 1.2.3 2026-09-01T00:00:00Z \
        KMU-1.2.3-en.zip:40 KMLib-1.2.3.zip:1 KMUX-1.2.3.zip:2 KMU-sources.zip:3 \
        KMU-1.2.zip:4 KMU-1.2.3-en.zip.sha256:5 xKMU-1.2.3.zip:6 KMU-1.2.3_zip:7)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.3 2026-09-01T00:00:00Z 40)" ]
}

@test "skips draft releases" {

    stub_pages "$(page \
        "$(release 1.3.0 draft KMU-1.3.0-en.zip:7)" \
        "$(release 1.2.3 2026-09-01T00:00:00Z KMU-1.2.3-en.zip:40)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.3 2026-09-01T00:00:00Z 40)" ]
}

@test "leaves out a release carrying no matching asset" {

    stub_pages "$(page \
        "$(release 1.2.4 2026-09-10T00:00:00Z kmu.version:9)" \
        "$(release 1.2.3 2026-09-01T00:00:00Z KMU-1.2.3-en.zip:40)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.3 2026-09-01T00:00:00Z 40)" ]
}

@test "lists releases newest first across pages" {

    # The second page holds the newest release, so an order taken from the
    # listing, or a sort run page by page, would put it last.
    stub_pages \
        "$(page \
            "$(release 0.1.0 2026-01-01T00:00:00Z KMU-0.1.0.zip:1)" \
            "$(release 1.2.3 2026-09-01T00:00:00Z KMU-1.2.3-en.zip:40)")" \
        "$(page "$(release 1.2.4 2026-09-10T00:00:00Z KMU-1.2.4-en.zip:3)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.4 2026-09-10T00:00:00Z 3)
$(summary_line 1.2.3 2026-09-01T00:00:00Z 40)
$(summary_line 0.1.0 2026-01-01T00:00:00Z 1)" ]
}

@test "orders by publish time, not by tag" {

    # A hotfix to an older line published after a higher version. Newest
    # means the release that went out last, which a sort by tag would bury.
    stub_pages "$(page \
        "$(release 1.3.0 2026-09-10T00:00:00Z KMU-1.3.0-en.zip:30)" \
        "$(release 1.2.4 2026-09-15T00:00:00Z KMU-1.2.4-en.zip:2)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.4 2026-09-15T00:00:00Z 2)
$(summary_line 1.3.0 2026-09-10T00:00:00Z 30)" ]
}

@test "reports a zero count for a matching asset nobody has downloaded" {

    # A release that ships a counted asset is a release, even before its
    # first download.
    stub_pages "$(page "$(release 1.2.4 2026-09-10T00:00:00Z KMU-1.2.4-en.zip:0)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(summary_line 1.2.4 2026-09-10T00:00:00Z 0)" ]
}

@test "lists every page of the given repository's releases" {

    stub_pages "$(page "$(release 1.2.3 2026-09-01T00:00:00Z KMU-1.2.3-en.zip:40)")"

    run "${SCRIPT}"

    [ "${status}" -eq 0 ]

    grep -qx "api" "${GH_ARGS_FILE}"
    grep -qx -- "--paginate" "${GH_ARGS_FILE}"
    grep -qx "repos/${REPO_UNDER_TEST}/releases?per_page=100" "${GH_ARGS_FILE}"
}

@test "fails when no release carries a matching asset" {

    stub_pages "$(page "$(release 1.2.3 2026-09-01T00:00:00Z kmu.version:9)")"

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no release of ${REPO_UNDER_TEST} carries an asset matching '${ZIP_NAME_REGEX}'"* ]]
}

@test "fails when the repository has no releases" {

    stub_pages "[]"

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no release of ${REPO_UNDER_TEST}"* ]]
}

@test "fails with gh's own message when the lookup fails" {

    export GH_STUB_STDERR="gh: Bad credentials (HTTP 401)" GH_STUB_EXIT=1

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"could not list the releases of ${REPO_UNDER_TEST}"* ]]
    [[ "${output}" == *"HTTP 401"* ]]
}

@test "fails naming the repository when gh's answer is not JSON" {

    # What a proxy's HTML error page or a truncated body looks like. jq's
    # parse error alone would not say which lookup it came from.
    stub_pages "<html>502 Bad Gateway</html>"

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"releases of ${REPO_UNDER_TEST} is not a releases listing"* ]]
}

@test "prints nothing to stdout when it fails" {

    # A caller publishing from stdout must not mistake a partial listing for
    # figures.
    export GH_STUB_STDOUT="$(page "$(release 1.2.3 2026-09-01T00:00:00Z KMU-1.2.3-en.zip:40)")"
    export GH_STUB_EXIT=1

    "${SCRIPT}" > "${BATS_TEST_TMPDIR}/stdout" 2> /dev/null || true

    [ ! -s "${BATS_TEST_TMPDIR}/stdout" ]
}

@test "requires the repository" {

    unset GITHUB_REPOSITORY

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"GITHUB_REPOSITORY is required"* ]]

    # Cheapest checks first: an incomplete invocation costs no API call.
    [ ! -f "${GH_ARGS_FILE}" ]
}

@test "requires the asset name regex" {

    unset ASSET_NAME_REGEX

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"ASSET_NAME_REGEX is required"* ]]
    [ ! -f "${GH_ARGS_FILE}" ]
}

@test "fails on an invalid regex without calling gh" {

    export ASSET_NAME_REGEX='^KMU-(\.zip$'

    run "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"ASSET_NAME_REGEX '^KMU-(\.zip\$' is not a valid regex"* ]]
    [ ! -f "${GH_ARGS_FILE}" ]
}
