#!/usr/bin/env bats
# Unit tests for resolve-role-color.sh.
# Run with: bats .github/lib/log-records/presenters/resolve-role-color.bats

# shellcheck source=SCRIPTDIR/resolve-role-color.sh
source "${BATS_TEST_DIRNAME}/resolve-role-color.sh"

@test "maps each coloured role to its colour" {

    while IFS=: read -r role expected_color; do

        resolve_role_color "${role}"

        [ "${role_color}" = "${expected_color}" ]
    done <<'PAIRS'
id:yellow
count:green
current:green
stale:grey
invalid:red
PAIRS
}

@test "leaves plain words, a locale and an unknown role uncoloured" {

    local role

    for role in "" locale unknown; do

        resolve_role_color "${role}"

        [ -z "${role_color}" ]
    done
}
