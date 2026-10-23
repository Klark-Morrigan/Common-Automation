#!/usr/bin/env bash
# Turns a path into the form docker run -v reads as a host path. Sourced, not
# executed: defines resolve_docker_host_path.
#
# Under Git Bash on Windows, docker is a Windows program, and the scripts call
# it with MSYS_NO_PATHCONV=1 so the container side of a mount (/repo) is not
# rewritten. That leaves the host side as written. A /c/... path happens to
# mount, but /tmp/... names no folder on the Windows host, so the mount comes
# up empty and the linter reports every file missing. cygpath -m gives the
# C:/... form, which docker mounts whatever the MSYS path was.
#
# Elsewhere there is no cygpath, and the path already is the host path.

# Prints the host form of the given path.
#   resolve_docker_host_path <path>
resolve_docker_host_path() {

    if command -v cygpath > /dev/null 2>&1; then

        cygpath -m "$1"
        return 0
    fi

    printf '%s\n' "$1"
}
