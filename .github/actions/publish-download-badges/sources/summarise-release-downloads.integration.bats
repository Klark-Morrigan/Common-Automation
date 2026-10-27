#!/usr/bin/env bats
# Integration tests for summarise-release-downloads.sh with the terminal
# presenter that shapes its log.
# Run with: bats .github/actions/publish-download-badges/sources/summarise-release-downloads.integration.bats
#
# gh is stubbed with a releases listing; the script, its jq passes, the log
# record writers and the presenter all run for real, so a case reads the log a
# person sees from the dry run.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/command-stub.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/command-stub.bash"

# shellcheck source=SCRIPTDIR/../../../lib/test-helpers/require-command.bash
source "${BATS_TEST_DIRNAME}/../../../lib/test-helpers/require-command.bash"

# shellcheck source=SCRIPTDIR/release-listing-fixtures.bash
source "${BATS_TEST_DIRNAME}/release-listing-fixtures.bash"

SCRIPT="${BATS_TEST_DIRNAME}/summarise-release-downloads.sh"
PRESENT_LOG_FOR_TERMINAL="${BATS_TEST_DIRNAME}/../../../lib/log-records/presenters/present-log-for-terminal.sh"
ZIP_NAME_REGEX='^tool-[0-9]+\.[0-9]+\.[0-9]+(-(?<locale>.+))?\.zip$'

setup() {

    # Without jq there is no filter to run, so nothing meaningful to assert.
    require_command jq

    install_command_stub gh

    export GITHUB_REPOSITORY="example-owner/example-tool"
    export ASSET_NAME_REGEX="${ZIP_NAME_REGEX}"
    export DEFAULT_LOCALE="en"

    # A tester's own colour settings must not reach the shaped log.
    unset NO_COLOR FORCE_COLOR
}

@test "writes a log the terminal presenter shapes into padded tables" {

    stub_pages "$(build_page \
        "$(build_release 1.3.0 draft tool-1.3.0-en.zip:7)" \
        "$(build_release 1.2.3 2026-09-01T00:00:00Z tool-1.2.3.zip:5 tool-1.2.3-zh-hans.zip:15 tool-en.manifest:800)")"

    run --separate-stderr "${SCRIPT}"

    [ "${status}" -eq 0 ]

    run "${PRESENT_LOG_FOR_TERMINAL}" <<< "${stderr}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "Listing the releases of example-owner/example-tool.
Counting the assets whose name matches '${ZIP_NAME_REGEX}'.
DEFAULT_LOCALE: EN, for a counted asset whose name holds no locale.
Release 1.2.3, published 2026-09-01T00:00:00Z:
Status   Asset                   Locale   Locale origin   Downloads  Note
counted  tool-1.2.3.zip          EN       DEFAULT_LOCALE          5
counted  tool-1.2.3-zh-hans.zip  ZH-HANS  name                   15
ignored  tool-en.manifest                                       800  its name does not match
Skipped draft 1.3.0: a draft has no downloads to report.
Release  Published             Locale   Downloads
1.2.3    2026-09-01T00:00:00Z  EN               5
1.2.3    2026-09-01T00:00:00Z  ZH-HANS         15
-------------------------------------------------
                               EN               5
                               ZH-HANS         15" ]
}
