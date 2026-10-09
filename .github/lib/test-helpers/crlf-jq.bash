#!/usr/bin/env bash
# Shared stand-in for the native Windows jq that Git Bash finds, for the bats
# suites of scripts that read jq's output. Sourced - never run - so it carries
# no tests itself and is skipped by the recursive *.bats runner.
#
# That jq ends every line with CRLF. A Linux runner never shows it, so a suite
# proves its script copes by running the real jq through this wrapper.

# shellcheck source=./path-stub.bash
source "${BASH_SOURCE[0]%/*}/path-stub.bash"

# Puts a jq wrapper first on PATH that runs the real jq and turns every line
# ending into CRLF.
install_crlf_jq() {

    local real_jq

    real_jq="$(command -v jq)"

    install_path_stub jq <<WRAPPER
#!/usr/bin/env bash
set -o pipefail
"${real_jq}" "\$@" | sed -e 's/\$/\r/'
WRAPPER
}
