# Runner Script Names

Issue: [#129](https://github.com/Klark-Morrigan/Common-Automation/issues/129)

- [Problem](#problem)
  - [What the names say and what runs](#what-the-names-say-and-what-runs)
  - [Where the names reach](#where-the-names-reach)
  - [What it must be](#what-it-must-be)

## Problem

The three local runner entry points are named for YAML and bash,
but they run every check Common-Automation's three CI workflows run, Markdown included.
A name no longer says what a run covers, and each new check widens the gap.

### What the names say and what runs

| Entry point | The name says | It runs |
| --- | --- | --- |
| `run-lint-yaml-and-bash.sh` | YAML and bash lint | shellcheck over four trees, check-sh-executable, actionlint, action-validator, yamllint, markdownlint |
| `run-tests-bash.sh` | bash tests | every bats suite git tracks |
| `run-ci-yaml-and-bash.sh` | CI for YAML and bash | both halves: the local equivalent of `ci-yaml`, `ci-markdown` and `ci-bash` |

The halves behind them, `_run-lint-yaml-and-bash.sh` and `_run-tests-bash.sh`, carry the same names.
Only `run-tests-bash.sh` says what it runs.

Planned work widens the gap:

- the [Mermaid lint plan](../115-mermaid-lint/plan.md) adds `mermaid-lint` to the lint half;
- the [shared batch launcher plan](../126-shared-bat-launcher/plan.md) adds `check-bat-launchers` to the lint half
  and a `windows tests` check to `run-ci-yaml-and-bash.sh`.

### Where the names reach

- **Consumer shims**: 21 repositories carry all three entry points as shims that delegate here,
  each a `.sh` with its `.bat` launcher,
  and most of those repositories' READMEs name them.
- **This repository**: the runners and their suites, the README,
  the header comments of five action scripts and the `test-bats` action,
  and the open plans 115, 126 and 127.
- **Domain runners beside them**: `run-ci-gradle.sh`, `run-ci-dotnet.sh` and `run-lint-ansible.sh`
  sit in the same `scripts/` folders and follow a `run-<ci|lint>-<domain>` shape,
  and some of them call these runners.
- **The `.menu`**: its rows label and launch them,
  and their labels already list fewer checks than run:
  "yamllint, actionlint, action-validator, shellcheck".
- **The agent tooling**: its repo-script allow list names `run-ci-yaml-and-bash` and `run-lint-yaml-and-bash`,
  and its repo-script policy, several skills and the WSL task runner name them too.

### What it must be

- **Says what runs**: each name says what its run covers,
  and stays true when a check is added;
  a name that lists tools goes stale with the next tool.
- **Fits beside the domain runners**: the names sit in one `scripts/` folder
  with `run-ci-gradle.sh` and the others, read as the same family, and collide with none.
- **One rename everywhere**: every shim, launcher, README, `.menu` row and agent tooling reference moves,
  and no repository is left calling a name that no longer exists.
- **No broken window**: a consumer's shim delegates to this repository's master,
  so no consumer's shim fails at any point during the rollout.
- **Agents unprompted throughout**: the allow list covers each new name before an old one goes.
- **After the launcher template**: plan 126 renders every launcher from one template by name,
  so the rename lands after it and changes the template once, not 21 launchers by hand.
