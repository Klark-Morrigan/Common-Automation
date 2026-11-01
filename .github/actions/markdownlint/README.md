# markdownlint composite action

Lints every Markdown file git tracks in the caller repo through the pinned `davidanson/markdownlint-cli2` image,
against the repo's own root `.markdownlint.jsonc`.
markdownlint-cli2 is built on the same library as the VS Code extension,
so CI reports what the editor shows.

## Index

- [Config](#config)
- [What it lints](#what-it-lints)
- [Security](#security)
- [Retry behaviour](#retry-behaviour)
- [See also](#see-also)

## Config

A consuming repo carries the one-line root file:

```jsonc
{ "extends": "../Common-Automation/.markdownlint.jsonc" }
```

The path holds for sibling checkouts, as on a workstation.
In CI, Common-Automation is staged inside the workspace instead,
so the container recreates the sibling layout:
the repo at `/src/repo`, Common-Automation at `/src/Common-Automation`.
The editor and CI then read the same file, with no CI-only override.
When Common-Automation lints itself, it is mounted once, at `/src/Common-Automation`.

A repo with tracked Markdown but no root config fails the run, and the error names the one-line file.
Falling back to the family ruleset instead would let the editor and CI disagree.

## What it lints

The files `git ls-files '*.md'` lists, so generated trees such as `graphify-out/` and `build/` stay out without an exclude list.
A tracked file deleted from the work tree is left out.
With no tracked Markdown the action skips with a `::notice::`, so it is safe to wire in first.

Files are passed after `--`, so markdownlint-cli2 reads a name holding `[`, `*` or `!` as a literal path, not a glob.

## Security

- Both mounts are read-only: CI never runs `--fix`, which is unsafe on these docs anyway.
- `docker run --network none`: linting needs no network,
  so a compromised image or a malicious custom rule cannot phone home.

## Retry behaviour

The `docker pull` of the pinned image is wrapped by [the retry primitive](../retry/README.md)
with the registry classifier set (`RETRY_CLASSIFIER_SET_REGISTRY`),
so a transient registry failure recovers instead of failing the run.
The `docker run` that lints is not wrapped: a finding is a real failure and fails fast.

## See also

- [Top-level Retry primitive subsection](../../../README.md#retry-primitive)
  for the primitive contract, env vars, and shipped classifiers.
- [Markdown lint config](../../../README.md#markdown-lint-config) for the family ruleset.
