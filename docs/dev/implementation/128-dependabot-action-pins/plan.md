# Dependabot for Action Pins

Issue: [#128](https://github.com/Klark-Morrigan/Common-Automation/issues/128)

- [Problem](#problem)
  - [What the pins are today](#what-the-pins-are-today)
  - [What Dependabot costs](#what-dependabot-costs)
  - [What it must be](#what-it-must-be)
- [Solution approach](#solution-approach)
  - [Candidates](#candidates)
  - [Against the requirements](#against-the-requirements)
  - [Left out](#left-out)
  - [Still to confirm](#still-to-confirm)

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

## Solution approach

**Direction: Dependabot, plus a drift gate.**
Each repository holds a `dependabot.yml` generated from one template in Common-Automation,
and a check in the `ci-yaml` reusable workflow fails a repository whose copy is missing or differs.

- Dependabot is GitHub's own service, so no outside party gains write access to the account's repositories,
  private ones included.
- It meets every point of [What it must be](#what-it-must-be);
  the floating tags take one conversion by hand, and the drift gate keeps new ones out.
- What it costs over Renovate: the template, the drift check and their tests are code to own,
  and `versions.env` stays bumped by hand.

### Candidates

| | Dependabot, plus a drift gate | Renovate, through Mend's hosted app |
| --- | --- | --- |
| Source and steward | GitHub's own service; [dependabot-core](https://github.com/dependabot/dependabot-core) is MIT | [Renovate](https://github.com/renovatebot/renovate), AGPL-3.0, run by Mend; releases every few days |
| Price | Free; its jobs [use no Actions minutes](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependabot-on-actions) | [Free](https://github.com/apps/renovate) for public and private repositories; runs on Mend's machines |
| What each repository holds | A full `dependabot.yml` | A one-line `renovate.json` naming a shared preset |
| One source | None built in: no `extends`, and YAML anchors fail to parse. The template lives in Common-Automation, and a check in the `ci-yaml` reusable workflow, which every repository calls at `@master`, fails a repository whose copy differs | The preset in one repository, `extends: ["github>Klark-Morrigan/<repository>"]`; a change there reaches every repository on its next run |
| Floating tags | Kept in the form found; converted by hand once, and the drift gate can refuse new ones | [`helpers:pinGitHubActionDigests`](https://docs.renovatebot.com/presets-helpers/) converts them and keeps the version comment |
| `@master` | Not documented; see [Still to confirm](#still-to-confirm) | [Pinned to a commit](https://docs.renovatebot.com/modules/manager/github-actions/) unless the preset excludes `Klark-Morrigan/*` |
| Pins outside workflows | npm only; it cannot read `versions.env` or a Dockerfile `ARG` | npm, and [custom managers](https://docs.renovatebot.com/modules/manager/) can bump `versions.env` keys and the Dockerfile's `NODE_VERSION` |
| Security | First party: no outside service gains access | A third-party app with write access to code, pull requests and workflows in every repository it is installed on, private ones included |
| Build | The template, the drift check and its tests | The preset; no code |

### Against the requirements

| [Requirement](#what-it-must-be) | Dependabot, plus a drift gate | Renovate |
| --- | --- | --- |
| Every repository, including later ones | The drift gate fails a repository without the file, once it calls `ci-yaml` | Installed for all repositories, the app proposes its config to each new one |
| One source | Copies stay, but the gate catches drift | Yes |
| SHA pins stay SHA pins | Yes | Yes |
| No floating tags | One conversion by hand | Yes |
| `@master` left alone | To confirm | With a rule in the preset |
| Releases at least two weeks old | `cooldown: default-days: 14` | `minimumReleaseAge: "14 days"` |
| Few pull requests | `groups` | `groupName` and a weekly `schedule` |
| Through the gates | Yes | Yes |
| Shares the file with the Mermaid lint `npm` entry | Yes | Covers npm too, so the Mermaid lint plan would move to Renovate |
| KMLib releases proposed | Yes, since it updates reusable workflow refs | Yes |

### Left out

- **GitHub's [action lockfile](https://docs.github.com/en/actions/how-tos/secure-your-work/lock-workflow-dependencies)
  and [SHA pinning policy](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/)**:
  a lockfile freezes a branch ref at its locked commit,
  and the policy fails a run that uses an unpinned action;
  25 `@master` references call composite actions on the account, in 8 files, and would stop tracking their branch or fail.
- **Renovate run by this repository**, through a scheduled workflow:
  as Renovate above, plus a token with write access to every repository kept in this repository's secrets.
- **A file-sync action** such as [repo-file-sync-action](https://github.com/BetaHuhn/repo-file-sync-action),
  which opens a pull request in each listed repository when the template changes:
  it needs a token with write access to every repository, and a hand-kept list of them, which a new repository is missing from.

### Still to confirm

- Dependabot leaves a `@master` branch ref alone.
- Dependabot reads composite actions under `.github/actions/*` when `directories` lists that glob.
- Renovate's app, installed for all repositories, onboards a repository created later without someone enabling it.
