# Dependabot for Action Pins

Issue: [#128](https://github.com/Klark-Morrigan/Common-Automation/issues/128)

- [Problem](#problem)
  - [What the pins are today](#what-the-pins-are-today)
  - [What Dependabot costs](#what-dependabot-costs)
  - [What it must be](#what-it-must-be)

## Problem

Every action a workflow uses is pinned by hand, and nothing says when a pin falls behind,
so a pin moves only when someone happens to look.
Dependabot would open a pull request for each new release,
and each repository's existing gates would check it like any other change.

No repository on the Klark-Morrigan account has a `.github/dependabot.yml` today.

### What the pins are today

Twenty-one repositories on the account hold GitHub Actions workflows.
Their workflows and composite actions hold 158 `uses:` references:

| Reference | Count | Example | Moves when |
| --- | --- | --- | --- |
| Full commit SHA with a version comment | 39 | `actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5.0.1` | Someone edits it |
| `@master` of a Common-* repository | 110 | `Klark-Morrigan/Common-Automation/.github/workflows/ci-bash.yml@master` | Common-* merges to master |
| Floating major tag | 10 | `actions/checkout@v5` | The action's owner moves the tag |
| Release tag of a reusable workflow on the account | 2 | `Klark-Morrigan/Starsector-Mod-KMLib/.github/workflows/mod-release.yml@0.5.2` | Someone edits it |

The standing convention is the first row: a full commit SHA, since a tag can be moved under a pin.
The ten floating tags break it:

| Repository | File | References |
| --- | --- | --- |
| Common-DotNet | `.github/workflows/ci-dotnet.yml` | `actions/checkout@v5` three times, `actions/upload-artifact@v7` |
| Common-DotNet | `.github/actions/provision-dotnet-toolchain/action.yml` | `actions/setup-dotnet@v5` |
| Infrastructure-E2E | `.github/workflows/e2e.yml` | `actions/create-github-app-token@v3` |
| Infrastructure-GitHub, Infrastructure-HyperV, Infrastructure-Network-Windows, Infrastructure-Wsl | `.github/workflows/release.yml` | `actions/checkout@v5` |

None of them is meant to float: no comment beside them says so,
and Common-DotNet's own plan asks for pins by commit SHA.
Common-DotNet's README names its steps by tag too, and has already drifted:
it lists `actions/upload-artifact@v4` where the workflow holds `@v7`.

No list of the account's repositories exists to roll a change out from.
`.menu/supersets.psd1` lists repositories for graphify only, and five of the twenty-one are missing from it.

### What Dependabot costs

- **Adding it**: one `.github/dependabot.yml` in each repository.
- **Running it**: Dependabot's own jobs on standard GitHub-hosted runners
  [do not count against included Actions minutes](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependabot-on-actions).
- **The pull requests' CI**: free on hosted runners for the seventeen public repositories.
  The four private ones spend minutes when their gates run on hosted runners, and nothing on self-hosted ones.
- **Review**: each pull request still needs a review and a merge.

### What it must be

- **Every repository**: each account repository with workflows is covered, twenty-one today,
  and a repository added later is covered without someone having to remember it.
- **One source**: the configuration is written once;
  twenty-one hand-kept copies would drift.
- **SHA pins stay SHA pins**: a bump moves the SHA and its version comment together.
- **No floating tags**: the ten above become SHA pins,
  since Dependabot keeps a reference in the form it finds it,
  and no README restates a pin that its workflow already holds.
- **`@master` left alone**: the calls into Common-* track the branch on purpose
  (see [Pinning](../../../../README.md#pinning)), and a bump must never pin them.
- **Releases at least two weeks old**: `cooldown: default-days: 14`,
  above Dependabot's default of three days.
- **Few pull requests**: one grouped pull request per repository per week at most.
- **Through the gates**: a bump merges only through the repository's existing pull request gates.
  Dependabot adds no check of its own.
- **Shares the file**: Common-Automation's `dependabot.yml` also carries the `npm` entry
  of the [Mermaid lint plan](../115-mermaid-lint/plan.md#the-image).
- **KMLib releases proposed**: the two references to KMLib's `mod-release.yml` pin a release tag on purpose,
  and a new KMLib release reaches them as a pull request, like any other action's.
