# Problem: Lint YAML workflows

## Index

- [What is changing](#what-is-changing)
- [Why](#why)
- [Solution approach](#solution-approach)
- [Out of scope](#out-of-scope)
- [References](#references)

## What is changing

Add an `actionlint` static-analysis gate over the repo's GitHub Actions
YAML, wired into both the local pre-push runner (`scripts/run-tests.sh`)
and CI (new reusable workflow `ci-yaml.yml`). Consumer repos pick it up
the same way they pick up `ci-bash.yml`.

## Why

Workflow YAML currently has no automated check. Bash inside `run:` blocks
is invisible to our standalone shellcheck job. Schema errors, bad
`uses:`/`needs:` references, and broken `${{ }}` expressions only surface
when a CI run is wasted on the remote.

A concrete recent example: a malformed `run:` line in
[.github/actions/assert-secret/action.yml](../../../.github/actions/assert-secret/action.yml)
broke every downstream consumer of `GitHub-Common@master` until it was
caught manually. Any YAML parser would have flagged it; `actionlint`
would have caught it plus the class of bugs around it.

## Solution approach

Off-the-shelf survey already done in
[research.md](research.md#tool-survey). Key findings:

- `actionlint` (rhysd) covers GitHub Actions schema, `uses:`/`needs:`
  validation, `${{ }}` expression checks, AND embeds shellcheck on every
  `run: |` block.
- `yamllint` adds a formatting layer (indentation, line length, etc.)
  but is most valuable for non-workflow YAML, of which this repo has
  none today.
- Marketplace wrappers (`reviewdog/action-actionlint`, others) add
  another action dependency for marginal UX gain.

**Chosen direction: adopt `actionlint` alone.** Best coverage-vs-friction
ratio. Slots into the existing local + CI dual-track pattern with no
new architecture. Defer `yamllint` until non-workflow YAML appears.

## Out of scope

- `yamllint` and other formatting-only checks (deferred).
- `act` for local workflow execution (debug tool, not a lint).
- Action-version pinning policy (`pin-github-action`, `ratchet`) - a
  separate concern, already handled by manual SHA pinning.
- Linting YAML outside `.github/` - none exists in this repo today.

## References

- [research.md](research.md) - off-the-shelf survey and wiring sketch.
- [scripts/run-tests.sh](../../../scripts/run-tests.sh) - local runner
  pattern to mirror.
- [.github/workflows/ci-bash.yml](../../../.github/workflows/ci-bash.yml)
  - reusable-workflow shape to mirror as `ci-yaml.yml`.
- [.github/lib/versions.env](../../../.github/lib/versions.env) - single
  source of truth for pinned tool versions.
