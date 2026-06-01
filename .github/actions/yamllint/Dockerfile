# Builds a tiny image that bundles the pinned yamllint version from
# PyPI. The upstream cytopia/yamllint Docker image only tags by major
# version (`1`, `latest`), so it cannot satisfy the repo's "pinned to
# an exact version" contract; we package our own image to give the
# helper the same docker-only ergonomics actionlint has via
# rhysd/actionlint, with single-source-of-truth versioning via
# .github/lib/versions.env.
#
# VERSION is required and pinned by .github/lib/versions.env via the
# get-yamllint-version.sh getter - the helper script passes it in as
# a build arg so a bump there propagates with no edits here.
FROM python:3.12-alpine

ARG VERSION

# --no-cache-dir keeps the layer small; the explicit `==${VERSION}`
# pin makes a missing/typoed version fail the build loudly rather
# than silently floating to whatever pip resolves.
RUN pip install --no-cache-dir "yamllint==${VERSION}"

ENTRYPOINT ["yamllint"]
