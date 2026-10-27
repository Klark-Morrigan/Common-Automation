#!/usr/bin/env bats
# Unit tests for jq-log-record-args.sh.
# Run with: bats .github/lib/log-records/writers/jq-log-record-args.bats

# shellcheck source=SCRIPTDIR/../../test-helpers/require-command.bash
source "${BATS_TEST_DIRNAME}/../../test-helpers/require-command.bash"

# shellcheck source=SCRIPTDIR/jq-log-record-args.sh
source "${BATS_TEST_DIRNAME}/jq-log-record-args.sh"

setup() {

    # Without jq there is nothing to hand the arguments to.
    require_command jq
}

# Prints the named argument jq reads for the given constant.
#   print_jq_named_arg <constant name>
print_jq_named_arg() {

    jq -nr "${JQ_LOG_RECORD_ARGS[@]}" --arg name "$1" '$ARGS.named[$name]'
}

@test "hands jq each format constant under its own name" {

    [ "$(print_jq_named_arg LOG_RECORD_MARKER)" = "#log" ]
    [ "$(print_jq_named_arg LOG_RECORD_SEPARATOR)" = "$(printf '\t')" ]
    [ "$(print_jq_named_arg LOG_RECORD_KIND_ROW)" = "row" ]
}

@test "hands jq each role under its own name, the plain role empty" {

    [ "$(print_jq_named_arg LOG_ROLE_ID)" = "id" ]
    [ "$(print_jq_named_arg LOG_ROLE_LOCALE)" = "locale" ]
    [ "$(jq -n "${JQ_LOG_RECORD_ARGS[@]}" '$ARGS.named | has("LOG_ROLE_PLAIN")')" = "true" ]
    [ -z "$(print_jq_named_arg LOG_ROLE_PLAIN)" ]
}

@test "holds the same arguments when sourced twice" {

    local expected_args=("${JQ_LOG_RECORD_ARGS[@]}")

    # shellcheck source=SCRIPTDIR/jq-log-record-args.sh
    source "${BATS_TEST_DIRNAME}/jq-log-record-args.sh"

    [ "${JQ_LOG_RECORD_ARGS[*]}" = "${expected_args[*]}" ]
}
