# Builds a tiny image that bundles the pinned ansible-lint version
# from PyPI. The upstream ghcr.io/ansible/community-ansible-lint image
# does not publish exact-version tags reliably across the pin window,
# so we package our own to satisfy the repo's "pinned to an exact
# version" contract - same rationale as the yamllint composite.
#
# VERSION is required and pinned by .github/lib/versions.env via the
# get-ansible-lint-version.sh getter - the helper script passes it in
# as a build arg so a bump there propagates with no edits here.
#
# Base: python:3.12-slim (Debian) rather than alpine because
# ansible-lint pulls in ansible-core, cryptography, and ruamel.yaml,
# all of which ship manylinux wheels but not musllinux - alpine would
# force a full toolchain install and a much larger final image.
FROM python:3.12-slim

ARG VERSION

# git is a runtime dependency of ansible-lint's collection discovery
# (it shells out to git for some repo-relative path resolution). The
# explicit `==${VERSION}` pin makes a missing/typoed version fail the
# build loudly rather than silently floating to whatever pip resolves.
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    pip install --no-cache-dir "ansible-lint==${VERSION}"

ENTRYPOINT ["ansible-lint"]
