#!/usr/bin/env bats
# Unit tests for summarise-release-downloads.sh.
# Run with: bats .github/actions/publish-download-badges/summarise-release-downloads.bats
#
# The gh stub replays a releases listing built by the helpers below, in the
# shape gh prints with --paginate and no --jq: one JSON array per page, back to
# back. jq runs for real, since the filter over that listing is what is under
# test.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/crlf-jq.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/crlf-jq.bash"

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/command-stub.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/command-stub.bash"

# shellcheck source=SCRIPTDIR/release-summary-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-summary-fixtures.bash"

SCRIPT="${BATS_TEST_DIRNAME}/summarise-release-downloads.sh"
REPO_UNDER_TEST="example-owner/example-tool"

# The tool's zip, plain or with a locale suffix. Anything else on a release -
# the polled manifests above all - is left out of the count.
ZIP_NAME_REGEX='^tool-[0-9]+\.[0-9]+\.[0-9]+(-(?<locale>.+))?\.zip$'

setup() {

    # Without jq there is no filter to run, so nothing meaningful to assert.
    command -v jq > /dev/null 2>&1 || skip "jq not available in this environment"

    install_command_stub gh

    export GITHUB_REPOSITORY="${REPO_UNDER_TEST}"
    export ASSET_NAME_REGEX="${ZIP_NAME_REGEX}"

    # The locale the plain zips were built in.
    export DEFAULT_LOCALE="en"

    # A retry would otherwise sleep for seconds between attempts.
    export RETRY_BACKOFF_INITIAL_SECONDS=0
}

# Emits one release object, given its tag, its publish time, and its assets as
# "<name>:<download count>" pairs. A draft is stated with "draft" in place of
# the time, because a draft carries no publish time.
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
build_page() {

    local IFS=,
    printf '[%s]' "$*"
}

# Makes the stub answer with the given pages, as gh prints them.
stub_pages() {

    export GH_STUB_STDOUT="$*"
}

@test "sums each locale's zips on a line of its own" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3-en.zip:40 tool-1.2.3-zh-hans.zip:15)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" ]
}

@test "counts an unlocalised zip under the default locale" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3.zip:5 tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 45)" ]
}

@test "counts every zip under the default locale when the regex has no locale group" {

    export ASSET_NAME_REGEX='^tool-[0-9]+\.[0-9]+\.[0-9]+(-.+)?\.zip$'
    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3.zip:5 tool-1.2.3-zh-hans.zip:15)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 20)" ]
}

@test "counts a zip whose locale group captured nothing under the default locale" {

    export ASSET_NAME_REGEX='^tool-[0-9]+\.[0-9]+\.[0-9]+-(?<locale>[a-z-]*)\.zip$'
    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3-.zip:5 tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 45)" ]
}

@test "sums unlocalised zips with no default locale on one line per release, its locale empty" {

    # A project keeping no locales: nothing names one, so nothing is guessed.
    unset DEFAULT_LOCALE
    stub_pages "$(build_page \
        "$(build_release 1.2.4 2026-09-10T00:00:00Z tool-1.2.4.zip:3)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z "" 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 40)" ]
}

@test "fails naming the asset when an unlocalised zip sits beside a localised one with no default locale" {

    unset DEFAULT_LOCALE
    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3-en.zip:40 tool-1.2.3.zip:5)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"asset 'tool-1.2.3.zip' of ${REPO_UNDER_TEST} names no locale"* ]]
}

@test "fails on an unlocalised zip with no default locale when another release's zip names one" {

    # The project keeps locales, so its older plain build belongs to one it
    # has not stated.
    unset DEFAULT_LOCALE
    stub_pages "$(build_page \
        "$(build_release 1.2.4 2026-09-10T00:00:00Z tool-1.2.4-en.zip:3)" \
        "$(build_release 0.1.0 2026-01-01T00:00:00Z tool-0.1.0.zip:1)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"asset 'tool-0.1.0.zip' of ${REPO_UNDER_TEST} names no locale"* ]]
}

@test "counts unlocalised zips under no locale when only a draft names one" {

    # A draft is left out of the count, so it says nothing of the project.
    unset DEFAULT_LOCALE
    stub_pages "$(build_page \
        "$(build_release 1.3.0 draft tool-1.3.0-en.zip:7)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z "" 40)" ]
}

@test "leaves every polled manifest out of the count" {

    # Clients fetch these on every start, so they outnumber the zips many
    # times over - excluding them is the point of the script.
    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3-en.zip:40 tool.manifest:900 tool-en.manifest:800 tool-zh-hans.manifest:700)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" ]
}

@test "leaves assets the regex does not match out of the count" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3-en.zip:40 other-1.2.3.zip:1 toolx-1.2.3.zip:2 tool-sources.zip:3 \
        tool-1.2.zip:4 tool-1.2.3-en.zip.sha256:5 xtool-1.2.3.zip:6 tool-1.2.3_zip:7)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" ]
}

@test "skips draft releases" {

    stub_pages "$(build_page \
        "$(build_release 1.3.0 draft tool-1.3.0-en.zip:7)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" ]
}

@test "leaves out a release carrying no matching asset" {

    stub_pages "$(build_page \
        "$(build_release 1.2.4 2026-09-10T00:00:00Z tool.manifest:9)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" ]
}

@test "lists releases newest first across pages" {

    # The second page holds the newest release, so an order taken from the
    # listing, or a sort run page by page, would put it last.
    stub_pages \
        "$(build_page \
            "$(build_release 0.1.0 2026-01-01T00:00:00Z tool-0.1.0.zip:1)" \
            "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")" \
        "$(build_page "$(build_release 1.2.4 2026-09-10T00:00:00Z tool-1.2.4-en.zip:3)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 0.1.0 2026-01-01T00:00:00Z en 1)" ]
}

@test "orders by publish time, not by tag" {

    # A hotfix to an older line published after a higher version. Newest
    # means the release that went out last, which a sort by tag would bury.
    stub_pages "$(build_page \
        "$(build_release 1.3.0 2026-09-10T00:00:00Z tool-1.3.0-en.zip:30)" \
        "$(build_release 1.2.4 2026-09-15T00:00:00Z tool-1.2.4-en.zip:2)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.4 2026-09-15T00:00:00Z en 2)
$(build_summary_line 1.3.0 2026-09-10T00:00:00Z en 30)" ]
}

@test "orders releases published at the same time by tag, whatever the listing's order" {

    # Two releases published together, as a script publishing both at once
    # could. Without a tie-break their order would follow the listing's.
    local release_a release_b

    release_a="$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)"
    release_b="$(build_release 1.2.4 2026-09-01T00:00:00Z tool-1.2.4-en.zip:3)"

    local expected_summary
    expected_summary="$(build_summary_line 1.2.4 2026-09-01T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)"

    stub_pages "$(build_page "${release_a}" "${release_b}")"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${expected_summary}" ]

    stub_pages "$(build_page "${release_b}" "${release_a}")"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${expected_summary}" ]
}

@test "lists one release's locales in tag order, under the release's place" {

    # The assets come in reverse tag order, so an order taken from the
    # listing would put zh-hans first.
    stub_pages "$(build_page \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-zh-hans.zip:15 tool-1.2.3-en.zip:40)" \
        "$(build_release 1.2.4 2026-09-10T00:00:00Z tool-1.2.4-zh-hans.zip:1 tool-1.2.4-en.zip:3)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.4 2026-09-10T00:00:00Z zh-hans 1)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z zh-hans 15)" ]
}

@test "reports a zero count for a matching asset nobody has downloaded" {

    # A release that ships a counted asset is a release, even before its
    # first download.
    stub_pages "$(build_page "$(build_release 1.2.4 2026-09-10T00:00:00Z tool-1.2.4-en.zip:0)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 0)" ]
}

@test "strips the carriage returns a native Windows jq writes" {

    # The listing is built before the wrapper goes on PATH, so only the
    # script's own jq call writes CRLF.
    stub_pages "$(build_page \
        "$(build_release 1.2.4 2026-09-10T00:00:00Z tool-1.2.4-en.zip:3)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"

    install_crlf_jq

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_summary_line 1.2.4 2026-09-10T00:00:00Z en 3)
$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" ]
}

@test "logs the repository, the regex and the default locale it reads with" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Listing the releases of ${REPO_UNDER_TEST}."* ]]
    [[ "${stderr}" == *"Counting the assets whose name matches '${ZIP_NAME_REGEX}'."* ]]
    [[ "${stderr}" == *"DEFAULT_LOCALE: en, for a counted asset whose name holds no locale."* ]]
}

@test "logs a counted asset with its count, its locale and where the locale came from" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3.zip:5 tool-1.2.3-zh-hans.zip:15)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Release 1.2.3, published 2026-09-01T00:00:00Z:
  counted tool-1.2.3.zip: 5 downloads, locale en from DEFAULT_LOCALE.
  counted tool-1.2.3-zh-hans.zip: 15 downloads, locale zh-hans from its name."* ]]
}

@test "logs an ignored asset" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3-en.zip:40 tool-en.manifest:800)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"  ignored tool-en.manifest: its name does not match."* ]]
}

@test "logs a skipped draft" {

    stub_pages "$(build_page \
        "$(build_release 1.3.0 draft tool-1.3.0-en.zip:7)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Skipped draft 1.3.0: a draft has no downloads to report."* ]]
}

@test "logs that an unset default locale leaves unlocalised zips under no locale when none names one" {

    unset DEFAULT_LOCALE
    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3.zip:5)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"DEFAULT_LOCALE: unset, and no counted asset names a locale, so each counts under no locale."* ]]
    [[ "${stderr}" == *"  counted tool-1.2.3.zip: 5 downloads, no locale."* ]]
}

@test "logs the counted asset that has no locale before failing on it" {

    unset DEFAULT_LOCALE
    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3.zip:5 tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"DEFAULT_LOCALE: unset, and a counted asset names a locale, so one whose name holds none fails the run."* ]]
    [[ "${stderr}" == *"  counted tool-1.2.3.zip: 5 downloads, no locale."* ]]
}

@test "logs how many summary lines it wrote" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z \
        tool-1.2.3-en.zip:40 tool-1.2.3-zh-hans.zip:15)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Summarised 2 lines, one per release and locale."* ]]
}

@test "keeps its log off stdout, which holds the summary alone" {

    # A caller reads stdout as the summary, so one log line there would be
    # read as a malformed summary line.
    stub_pages "$(build_page \
        "$(build_release 1.3.0 draft tool-1.3.0-en.zip:7)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40 tool.manifest:9)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -n "${stderr}" ]
    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" ]
}

@test "lists every page of the given repository's releases" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]

    grep -qx "api" "${GH_ARGS_FILE}"
    grep -qx -- "--paginate" "${GH_ARGS_FILE}"
    grep -qx "repos/${REPO_UNDER_TEST}/releases?per_page=100" "${GH_ARGS_FILE}"
}

@test "retries a server error and counts only the attempt that succeeded" {

    # The failed attempt printed a page before failing. Kept beside the
    # retry's full listing, that page would be counted twice.
    export GH_STUB_STDOUT_1="$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"
    export GH_STUB_STDERR_1="gh: HTTP 502" GH_STUB_EXIT_1=1

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]
    [ "$(count_command_calls gh)" -eq 2 ]

    [ "${output}" = "$(build_summary_line 1.2.3 2026-09-01T00:00:00Z en 40)" ]
}

@test "fails without retrying when gh reports a client error" {

    # A bad token or a missing repository answers the same on every attempt.
    export GH_STUB_STDERR="gh: Bad credentials (HTTP 401)" GH_STUB_EXIT=1

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [ "$(count_command_calls gh)" -eq 1 ]

    [[ "${stderr}" == *"could not list the releases of ${REPO_UNDER_TEST}"* ]]
    [[ "${stderr}" == *"HTTP 401"* ]]
}

@test "fails when no release carries a matching asset" {

    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z tool.manifest:9)")"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"no release of ${REPO_UNDER_TEST} carries an asset matching '${ZIP_NAME_REGEX}'"* ]]
}

@test "fails when the repository has no releases" {

    stub_pages "[]"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"no release of ${REPO_UNDER_TEST}"* ]]
}

@test "fails naming the repository when gh's answer is not JSON" {

    # What a proxy's HTML error page or a truncated body looks like. jq's
    # parse error alone would not say which lookup it came from.
    stub_pages "<html>502 Bad Gateway</html>"
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"releases of ${REPO_UNDER_TEST} is not a releases listing"* ]]
}

@test "prints nothing to stdout when it fails" {

    # A caller publishing from stdout must not mistake a partial listing for
    # figures.
    stub_pages "$(build_page "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3-en.zip:40)")"
    export GH_STUB_EXIT=1

    "${SCRIPT}" > "${BATS_TEST_TMPDIR}/stdout" 2> /dev/null || true

    [ ! -s "${BATS_TEST_TMPDIR}/stdout" ]
}

@test "requires the repository" {

    unset GITHUB_REPOSITORY
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"GITHUB_REPOSITORY is required"* ]]

    # Cheapest checks first: an incomplete invocation costs no API call.
    [ ! -f "${GH_CALLS_FILE}" ]
}

@test "requires the asset name regex" {

    unset ASSET_NAME_REGEX
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"ASSET_NAME_REGEX is required"* ]]
    [ ! -f "${GH_CALLS_FILE}" ]
}

@test "fails on an invalid regex without calling gh" {

    export ASSET_NAME_REGEX='^tool-(\.zip$'
    run --separate-stderr "${SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"ASSET_NAME_REGEX '^tool-(\.zip\$' is not a valid regex"* ]]
    [ ! -f "${GH_CALLS_FILE}" ]
}
