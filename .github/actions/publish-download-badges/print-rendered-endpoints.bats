#!/usr/bin/env bats
# Unit tests for print-rendered-endpoints.sh.
# Run with: bats .github/actions/publish-download-badges/print-rendered-endpoints.bats

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

setup() {

    # shellcheck source=SCRIPTDIR/print-rendered-endpoints.sh
    source "${BATS_TEST_DIRNAME}/print-rendered-endpoints.sh"

    BADGE_DIR="${BATS_TEST_TMPDIR}/badges"
    mkdir -p "${BADGE_DIR}"
}

@test "prints each endpoint file by name, with its content, to stdout alone" {

    printf '{"message":"2066"}\n' > "${BADGE_DIR}/downloads.json"
    printf '{"message":"EN: 2060 | CN: 6"}\n' > "${BADGE_DIR}/downloads-by-locale.json"

    run --separate-stderr print_rendered_endpoints "${BADGE_DIR}"

    [ "${status}" -eq 0 ]
    [ "${output}" = 'downloads-by-locale.json: {"message":"EN: 2060 | CN: 6"}
downloads.json: {"message":"2066"}' ]
    [ -z "${stderr}" ]
}

# A renderer can exit 0 without writing; the dry run then shows no figure
# rather than a stray "*" line.
@test "prints nothing for an empty directory" {

    run print_rendered_endpoints "${BADGE_DIR}"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}
