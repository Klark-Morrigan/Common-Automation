#!/usr/bin/env bash
#
# Sources the declaration files a tier passes,
# widening the family-wide sets:
# the paths kept executable and the text types trimmed.
#
# Sourced, not executed: defines source_tier_declarations.
#
# A file that is absent is skipped.
# The fixes are conveniences,
# so a clone missing that tier's checkout still commits,
# and its runners still run, over the family-wide sets alone.
#
# The hook body and both manual runners call this,
# so they answer an absent file the same way.

# Loaded first, so a tier's += widens the family-wide sets
# rather than standing in for them.
# shellcheck source=SCRIPTDIR/executable-pathspecs.sh
source "${BASH_SOURCE[0]%/*}/executable-pathspecs.sh"

# shellcheck source=SCRIPTDIR/trimmed-file-types.sh
source "${BASH_SOURCE[0]%/*}/trimmed-file-types.sh"

#   source_tier_declarations [declaration_file...]
source_tier_declarations() {

    local declaration_file

    for declaration_file in "$@"; do

        if [[ -f "${declaration_file}" ]]; then

            # shellcheck source=/dev/null
            source "${declaration_file}"
        fi
    done
}
