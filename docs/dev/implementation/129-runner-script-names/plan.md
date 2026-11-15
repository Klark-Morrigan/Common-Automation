# Runner Script Names

Issue: [#129](https://github.com/Klark-Morrigan/Common-Automation/issues/129)

- [Problem](#problem)
  - [What the names say and what runs](#what-the-names-say-and-what-runs)
  - [Where the names reach](#where-the-names-reach)
  - [What it must be](#what-it-must-be)
- [Solution approach](#solution-approach)
  - [Naming candidates](#naming-candidates)
  - [Rollout candidates](#rollout-candidates)
  - [Recommendation](#recommendation)
- [Design](#design)
  - [What each entry runs](#what-each-entry-runs)
  - [Finding the domain runners](#finding-the-domain-runners)
  - [Consumer shims](#consumer-shims)
  - [Forwarders](#forwarders)
  - [Outside the repositories](#outside-the-repositories)
  - [Rollout order](#rollout-order)

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

## Solution approach

**Direction: `all` names in the family's own shape, rolled out through forwarders.**

| Today | Renamed |
| --- | --- |
| `run-lint-yaml-and-bash.sh` | `run-lint-all.sh` |
| `run-tests-bash.sh` | `run-tests-all.sh` |
| `run-ci-yaml-and-bash.sh` | `run-ci-all.sh` |
| `_run-lint-yaml-and-bash.sh` | `_run-lint-shared.sh` |
| `_run-tests-bash.sh` | `_run-tests-bash.sh`, unchanged |

- **What makes `all` true**: an `all` entry runs every local check of its kind that its repository has,
  its domain runners included.
  Consumer lint shims already work this way: those with Ansible content run `run-lint-ansible.sh` after the shared lint.
  `run-ci-all.sh` in a repository with `run-ci-gradle.sh` runs that too.
  Beside the domain runners, a bare `all` that ran only the shared checks would read as more than it is;
  under this contract it is exactly what it says.
- **The halves keep a narrow name**: `_run-lint-shared.sh` is the shared part every `all` entry starts from,
  and `_run-tests-bash.sh` already says what it runs.
- **Forwarders**: each old entry name stays as a forwarder that names its replacement and runs it,
  until no caller is left.
- **Why not `shared`**: it names only Common-Automation's part,
  so a repository with domain runners would still need a name for the whole run.

### Naming candidates

| | Scripts to Rule Them All | A task runner: [Task](https://taskfile.dev), [just](https://github.com/casey/just) or Make | Names in the family's own shape |
| --- | --- | --- | --- |
| What it is | GitHub's [normalized script pattern](https://github.blog/engineering/engineering-principles/scripts-to-rule-them-all/): `script/test`, `script/cibuild` and others, one per purpose, in every repository | Targets in one file, such as `task lint` or `just ci` | `run-<ci\|lint\|tests>-<domain>.sh`, as `run-ci-gradle.sh` already is |
| Source and licence | A convention; the [boilerplate](https://github.com/github/scripts-to-rule-them-all) is listed as CC0 | Task MIT, just CC0, Make GPL-3.0; all maintained | None needed |
| Fit | Names say the purpose and never go stale, but `script/test` would own every test in a repository, the domain runners' included: a wider change than this one | Names say the purpose; the file lists every check | Fits beside the domain runners with no new tool |
| Cost | Moves `scripts/` to `script/`, drops the extension, and reworks the domain runners | A binary on every workstation and runner, against the family's Docker-only tooling; the double-click launchers lose their target | Only the rename |
| Security | Nothing new | A new binary in every CI job, from a third party | Nothing new |

Within the family's own shape, two readings of what these runners cover:

- **What they do**: `run-lint.sh`, `run-tests.sh`, `run-ci.sh`.
  Short, but beside `run-ci-gradle.sh` a bare `run-ci.sh` reads as all of a repository's CI, which it is not.
- **Whose checks they are**: the checks every repository shares, supplied by this one:
  `run-lint-shared.sh` and `run-ci-shared.sh`, with `run-tests-bash.sh` kept, since it already says what it runs.
  The domain is `shared`, so the names read as one family with `run-ci-gradle.sh`,
  and they stay true as shared checks are added.

### Rollout candidates

| | Forwarders, then removal | Everything in one pass |
| --- | --- | --- |
| How | This repository adds the new names and turns each old one into a forwarder that names its replacement and runs it; consumers move one at a time; a last step removes the forwarders once no caller is left | Every repository renames on the same day |
| No broken window | Yes: an old shim keeps working until its repository moves | Only if every repository merges in the right order |
| Agents unprompted | The allow list gains the new names first and loses the old ones last | Needs the allow list changed in the same pass |
| Cost | One extra step at each end | One coordinated push across 21 repositories |

### Recommendation

Names in the family's own shape, with no new tool,
rolled out through forwarders,
with each consumer's launchers regenerated from plan 126's template.
The direction above settles the word: `all`, under the contract it states.

## Design

### What each entry runs

```mermaid
flowchart LR
    ciAll[run-ci-all.sh] --> lintAll[run-lint-all.sh]
    ciAll --> testsAll[run-tests-all.sh]
    ciAll --> ciDomain[Each run-ci domain runner]
    lintAll --> lintShared[_run-lint-shared.sh]
    lintAll --> lintDomain[Each run-lint domain runner]
    testsAll --> testsBash[_run-tests-bash.sh]
    testsAll --> testsDomain[Each run-tests domain runner]
```

| Entry | Runs, in order |
| --- | --- |
| `run-lint-all.sh` | `_run-lint-shared.sh`, then every `run-lint-<domain>.sh` the repository has |
| `run-tests-all.sh` | `_run-tests-bash.sh`, then every `run-tests-<domain>.sh` |
| `run-ci-all.sh` | `run-lint-all.sh`, `run-tests-all.sh`, then every `run-ci-<domain>.sh` |

- Each domain runner runs as one recorded check under its own heading,
  so a run still ends by naming every check that failed.
- A domain offers either `run-ci-<domain>.sh`,
  or `run-lint-<domain>.sh` and `run-tests-<domain>.sh`, never both,
  so no check runs twice.
  Today's domain runners keep to this: Gradle and .NET are `run-ci-`, Ansible is `run-lint-`.
- A domain runner never calls an `all` entry, so the composition cannot loop.

### Finding the domain runners

- Common-Automation's entries find them in the target repository's `scripts/`
  by the pattern `run-<kind>-<domain>.sh`, in name order.
- `all` and any name starting with `_` are not domains.
- A new domain runner joins its `all` entry by being named to the pattern; no list is edited.
- Consumer lint shims stop calling `run-lint-ansible.sh` themselves, since the entry now finds it.

### Consumer shims

- Every consumer shim becomes the same three lines:
  set `COMMON_AUTOMATION_TARGET_REPO` to its repository, then run Common-Automation's entry of the same name.
- No shim names a domain runner, so the shims match across repositories.
- The `.bat` launchers are rendered by [plan 126](../126-shared-bat-launcher/plan.md)'s writer,
  once for the new names and once for the forwarders.

### Forwarders

- Each old entry name, in Common-Automation and in every consumer, becomes a forwarder:
  it prints `<old name> is renamed <new name>; run that instead.` to stderr, then runs the new entry with its arguments,
  and exits with its code.
- The notice goes to stderr, so a caller reading stdout sees the same output as before.
- The forwarders go in a last step, once a search of every repository, the `.menu` and the agent tooling finds no caller.

### Outside the repositories

- **The `.menu`**: its rows launch the new names,
  and its labels say what runs without listing tools, such as "Lint: every check, shared and this repository's own".
- **The agent tooling**: the repo-script allow list gains `run-ci-all`, `run-lint-all` and `run-tests-all`
  before any caller moves,
  and loses the old names with the forwarders;
  the skills and the WSL task runner name the new entries.
  The settings files are protected, so the agent writes the change and the user approves it.

### Rollout order

Consumer shims call Common-Automation's master, so the order keeps every call working:

1. Common-Automation adds the new entries, the domain-runner finding and its own forwarders.
2. The agent tooling's allow list gains the new names.
3. Each repository moves its shims to the new names, keeps forwarders under the old ones,
   and drops its own call to a domain runner; one pull request each.
4. The `.menu` and the agent tooling move to the new names.
5. Every forwarder is removed, and the allow list loses the old names.
