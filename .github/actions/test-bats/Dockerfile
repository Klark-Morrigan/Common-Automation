# The image the local test half runs test-bats.sh in. CI never uses it: there
# action.yml installs bats on the runner itself.
#
# Ubuntu, not the upstream Alpine bats/bats, because CI runs the suites on an
# Ubuntu runner, and the suites need what it has: GNU coreutils, git and jq.
# GNU parallel lets the runner spread the suites over the cores. gawk takes
# over awk from Ubuntu's default mawk, which ignores the seed srand is given,
# as CI's runner does.
#
# VERSION is required and pinned by .github/lib/versions.env, read through
# get-tool-version.sh - _run-tests-bash.sh passes it in as a build arg.
# BATS_SHA256 is the checksum of that version's tarball, so a bump there fails
# this build until the checksum here follows it.

# Pinned by digest, so the base changes only when this file does: the runner
# tags the image with this file's checksum, and an edit misses its cache.
FROM ubuntu:24.04@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5 AS base

# A stage of its own, so curl and its certificates stay out of the image.
FROM base AS fetch

ARG VERSION
ARG BATS_SHA256=a85e12b8828271a152b338ca8109aa23493b57950987c8e6dff97ba492772ff3

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# The release tarball of the pinned tag, as CI's bats install fetches it. A
# missing or typoed version fails on curl's -f, a changed tarball on the
# checksum. install.sh lays bats out relative to its prefix, so the tree under
# /opt/bats works wherever it is copied.
RUN curl -fsSL -o /tmp/bats.tar.gz \
        "https://github.com/bats-core/bats-core/archive/refs/tags/v${VERSION}.tar.gz" && \
    echo "${BATS_SHA256}  /tmp/bats.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/bats.tar.gz -C /tmp && \
    "/tmp/bats-core-${VERSION}/install.sh" /opt/bats

FROM base

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        gawk git jq parallel python3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/bats/ /usr/local/

# CI runs the suites as an unprivileged user. As root, a case that takes a
# permission away would still find the file readable. The mounted checkout
# belongs to another user, so git is told to trust it rather than refuse.
RUN useradd --create-home tester && \
    git config --system safe.directory '*'

USER tester
