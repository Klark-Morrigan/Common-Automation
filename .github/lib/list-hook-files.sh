#!/usr/bin/env bash
# Lists the hook files a lint covers in a hooks directory. Sourced, not
# executed: defines list_hook_files.
#
# In a git work tree, only the files git tracks are hooks to lint. A hooks
# folder can also hold hooks a tool installs on one machine, such as
# graphify's post-commit, which the folder's .gitignore keeps out of the repo.
# A CI checkout never has them, so linting tracked files alone lints locally
# exactly what CI lints. Outside a work tree nothing tells the two apart, so
# every file counts.
#
# Top level only, since git runs hooks from there. A dotfile is never a hook,
# so the folder's own .gitignore is not linted.

# Prints each hook file as <hooks dir>/<name>, one per line, sorted by name.
# Prints nothing for a directory holding none.
#   list_hook_files <hooks dir>
list_hook_files() {

    local hooks_dir="$1"
    local names
    local name

    if git -C "${hooks_dir}" rev-parse --is-inside-work-tree > /dev/null 2>&1; then

        names="$(git -C "${hooks_dir}" ls-files)"
    else
        names="$(ls -A "${hooks_dir}")"
    fi

    while IFS= read -r name; do

        if [[ -z "${name}" || "${name}" == */* || "${name}" == .* || ! -f "${hooks_dir}/${name}" ]]; then
            continue
        fi

        printf '%s\n' "${hooks_dir}/${name}"

    done <<< "${names}"
}
