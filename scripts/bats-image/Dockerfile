# The image the local test half runs bats in when the host has no native bats.
#
# Ubuntu, not the upstream Alpine bats/bats, because CI runs the suites on an
# Ubuntu runner: GNU coreutils, git and jq are there, and the suites rely on
# them. On BusyBox they skipped every git case and failed on sort and cut.
# GNU parallel lets the runner spread the suites over the host's cores. gawk
# takes over awk from Ubuntu's default mawk, which ignores the seed srand is
# given, as CI's runner does.
#
# VERSION is required and pinned by .github/lib/versions.env, read through
# get-tool-version.sh - _run-tests-bash.sh passes it in as a build arg, so a
# bump there propagates with no edits here.
FROM ubuntu:24.04

ARG VERSION

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gawk git jq parallel python3 && \
    rm -rf /var/lib/apt/lists/*

# The release tarball of the pinned tag, as CI's bats install fetches it. A
# missing or typoed version fails the build on curl's -f rather than floating.
RUN curl -fsSL "https://github.com/bats-core/bats-core/archive/refs/tags/v${VERSION}.tar.gz" \
        | tar -xz -C /tmp && \
    "/tmp/bats-core-${VERSION}/install.sh" /usr/local && \
    rm -rf "/tmp/bats-core-${VERSION}"

# CI runs the suites as an unprivileged user. As root, a case that takes a
# permission away would still find the file readable. The mounted checkout
# belongs to another user, so git is told to trust it rather than refuse.
RUN useradd --create-home tester && \
    git config --system safe.directory '*'

USER tester

ENTRYPOINT ["bats"]
