#!/usr/bin/env bats
# Unit tests for summarise-nexus-downloads.sh.
# Run with: bats .github/actions/publish-download-badges/summarise-nexus-downloads.bats
#
# Each case feeds a files answer built by the helpers below, in the shape
# fetch-nexus-files.sh prints. jq runs for real, since the filter over that
# answer is what is under test.

# run --separate-stderr arrived in 1.5.0.
bats_require_minimum_version 1.5.0

# shellcheck source=SCRIPTDIR/../../lib/test-helpers/crlf-jq.bash
source "${BATS_TEST_DIRNAME}/../../lib/test-helpers/crlf-jq.bash"

SCRIPT="${BATS_TEST_DIRNAME}/summarise-nexus-downloads.sh"

setup() {

    # Without jq there is no filter to run, so nothing meaningful to assert.
    command -v jq > /dev/null 2>&1 || skip "jq not available in this environment"

    export NEXUS_FILE_NAME="tool"
    export NEXUS_LOCALE="en"
}

# Emits one file object, given its id, name, version, category, total
# downloads and unique downloads.
#   build_mod_file <file id> <name> <version> <category> <total> <unique>
build_mod_file() {

    jq -cn --argjson fileId "$1" --arg name "$2" --arg version "$3" --arg category "$4" \
        --argjson total "$5" --argjson unique "$6" \
        '{ fileId: $fileId, name: $name, version: $version, category: $category,
           totalDownloads: $total, uniqueDownloads: $unique }'
}

# Emits a files answer from the given file objects.
build_answer() {

    local IFS=,
    printf '{"data":{"modFiles":[%s]}}' "$*"
}

# Builds one summary line, without its newline:
#   build_nexus_line <version> <locale> <download count>
build_nexus_line() {

    printf '%s\t%s\t%s' "$1" "$2" "$3"
}

@test "prints one line per version under the given locale" {

    local answer
    answer="$(build_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 2 tool 1.2.2 OLD_VERSION 9 8)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "$(sort <<< "${output}")" = "$(build_nexus_line 1.2.2 en 9)
$(build_nexus_line 1.2.3 en 40)" ]
}

@test "leaves out the files of another name on the same page" {

    # One page can host several projects' files.
    local answer
    answer="$(build_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 2 other 1.2.3 MAIN 500 400)" \
        "$(build_mod_file 3 tool-extra 1.2.3 OPTIONAL 6 6)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_nexus_line 1.2.3 en 40)" ]
}

@test "counts archived files" {

    # An archived file keeps its downloads.
    local answer
    answer="$(build_answer "$(build_mod_file 1 tool 0.1.0 ARCHIVED 73 67)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_nexus_line 0.1.0 en 73)" ]
}

@test "sums two files of one version onto one line" {

    # A main file and an optional file of the same release.
    local answer
    answer="$(build_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 2 tool 1.2.3 OPTIONAL 5 5)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_nexus_line 1.2.3 en 45)" ]
}

@test "counts total downloads, not unique downloads" {

    # GitHub counts every download, so Nexus is counted the same way.
    local answer
    answer="$(build_answer "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_nexus_line 1.2.3 en 40)" ]
}

@test "reports a zero count for a file nobody has downloaded" {

    local answer
    answer="$(build_answer "$(build_mod_file 1 tool 1.2.4 MAIN 0 0)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_nexus_line 1.2.4 en 0)" ]
}

@test "leaves the locale field empty when no locale is given" {

    unset NEXUS_LOCALE

    local answer
    answer="$(build_answer "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(build_nexus_line 1.2.3 "" 40)" ]
    [[ "${stderr}" == *"Counting the Nexus files named 'tool', under no locale: NEXUS_LOCALE is unset."* ]]
}

@test "logs the name and locale it counts under" {

    local answer
    answer="$(build_answer "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Counting the Nexus files named 'tool', under locale en."* ]]
}

@test "logs each counted file with its id, version and count" {

    local answer
    answer="$(build_answer "$(build_mod_file 1187 tool 1.2.3 MAIN 40 30)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"  counted file 1187, version 1.2.3, MAIN: 40 downloads."* ]]
}

@test "logs each ignored file with its name" {

    local answer
    answer="$(build_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 1188 other 0.5.2 MAIN 63 59)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"  ignored file 1188, other 0.5.2: its name does not match."* ]]
}

@test "logs how many summary lines it wrote" {

    local answer
    answer="$(build_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 2 tool 1.2.2 OLD_VERSION 9 8)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Summarised 2 lines, one per version."* ]]
}

@test "keeps its log off stdout, which holds the summary alone" {

    local answer
    answer="$(build_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 2 other 0.5.2 MAIN 63 59)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ -n "${stderr}" ]
    [ "${output}" = "$(build_nexus_line 1.2.3 en 40)" ]
}

@test "strips the carriage returns a native Windows jq writes" {

    # The answer is built before the wrapper goes on PATH, so only the
    # script's own jq calls write CRLF.
    local answer
    answer="$(build_answer \
        "$(build_mod_file 1 tool 1.2.3 MAIN 40 30)" \
        "$(build_mod_file 2 tool 1.2.2 OLD_VERSION 9 8)")"

    install_crlf_jq

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -eq 0 ]
    [ "$(sort <<< "${output}")" = "$(build_nexus_line 1.2.2 en 9)
$(build_nexus_line 1.2.3 en 40)" ]
}

@test "fails naming the file name when no file carries it" {

    local answer
    answer="$(build_answer "$(build_mod_file 2 other 1.2.3 MAIN 500 400)")"

    run --separate-stderr "${SCRIPT}" <<< "${answer}"

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"no Nexus file is named 'tool'."* ]]
}

@test "fails naming the file name when the page has no files" {

    run --separate-stderr "${SCRIPT}" <<< "$(build_answer)"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"no Nexus file is named 'tool'."* ]]
}

@test "fails when stdin is not a files answer" {

    run --separate-stderr "${SCRIPT}" <<< '{"data":null}'

    [ "${status}" -ne 0 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"stdin is not a Nexus files answer."* ]]
}

@test "fails when stdin is empty" {

    run --separate-stderr "${SCRIPT}" < /dev/null

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"stdin is not a Nexus files answer."* ]]
}

@test "requires the file name" {

    unset NEXUS_FILE_NAME

    run --separate-stderr "${SCRIPT}" <<< "$(build_answer)"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"NEXUS_FILE_NAME is required"* ]]
}
