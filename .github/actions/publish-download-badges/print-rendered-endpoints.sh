#!/usr/bin/env bash
# Prints the endpoint files a run rendered, so a dry run shows the figures it
# would have published. Sourced, not executed: defines
# print_rendered_endpoints.

# Prints each file in the badge directory to stdout, by name, as
# "<file>: <content>". An empty directory prints nothing.
#   print_rendered_endpoints <badge directory>
print_rendered_endpoints() {

    local endpoint_file
    local endpoint

    for endpoint_file in "$1"/*; do

        # An empty directory leaves the glob unexpanded.
        if [[ ! -f "${endpoint_file}" ]]; then
            continue
        fi

        endpoint="$(< "${endpoint_file}")"
        printf '%s: %s\n' "${endpoint_file##*/}" "${endpoint}"
    done
}
