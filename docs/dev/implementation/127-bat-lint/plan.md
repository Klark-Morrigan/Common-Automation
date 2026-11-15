# Batch File Lint

Issue: [#127](https://github.com/Klark-Morrigan/Common-Automation/issues/127)

- [Problem](#problem)
  - [What a reader misses](#what-a-reader-misses)
  - [The trial](#the-trial)
  - [What it must be](#what-it-must-be)
- [Solution approach](#solution-approach)
  - [Candidates](#candidates)
  - [The design trial](#the-design-trial)
- [Design](#design)
  - [The run](#the-run)
  - [The config](#the-config)
  - [The image](#the-image)
  - [Where it runs](#where-it-runs)
  - [Runtime](#runtime)
  - [Security](#security)

## Problem

Nothing reads a batch file for the mistakes cmd trips on,
so LF-only line endings or code after an unconditional `exit` are found only when a launcher fails.
A pinned batch linter in the lint half would flag them on every pull request, beside shellcheck.

### What a reader misses

The launchers are short, and their failures are not visible in the text:

- A file with LF line endings looks the same as one with CRLF,
  but cmd can misread labels and `goto` targets in it.
  Six of Common-Automation's nine `.bat` files had LF working copies.
- A line split with `\` reads like a bash continuation,
  but cmd runs the next line on its own, so an `exit` meant for the failure path always runs.

The [shared launcher plan](../126-shared-bat-launcher/plan.md) catches what a launcher does by running it.
A linter is the cheaper check that needs no Windows runner, and it covers any batch file, not only the launchers.

### The trial

Blinter 1.1.73, run in a throwaway `python:3.12-slim` container:

| Case | Result |
| --- | --- |
| `call ... \|\| \` + `exit /b 1`, which always exits 1 | Caught as E008: the code after the `exit` can never run. It does not name the split itself. |
| `call ... \` + `\|\| exit /b 1`, a syntax error | Missed. |
| `call ... ^` + `\|\| exit /b 1`, correct | Clean. |
| LF-only line endings | Caught as E018, on all seven LF files. |

On Common-Automation's own `scripts/` it reported 54 findings, most of them noise for a launcher:

- S007, use `.cmd` over `.bat`, on every file;
- W028, `%errorlevel%` differs between `.bat` and `.cmd`;
- SEC014, `%*` passed on unescaped, which is the launcher's job;
- P003, `SETLOCAL` without a `SET`.

Release 1.1.73 is licensed AGPL-3.0-or-later.
The project releases often: 1.0.2 to 1.1.73 in the PyPI history.

### What it must be

- **Pinned**: one exact version of Blinter and of everything it installs, each checked against its hash,
  and named from `.github/lib/versions.env` where the other tool pins live.
- **Contained**: it runs in a container with no network, as the other dockerised linters do,
  so the package never runs on the host.
- **Quiet**: a shared config turns off the rules that do not fit a launcher,
  so a finding means something to fix.
- **Same everywhere**: one helper runs it for an agent, for the user and in CI, from the lint half.
- **Skips cleanly**: a repository with no batch files passes without starting the container.
- **Cheap**: a run over a repository's batch files stays within a few seconds once the image is built.

## Solution approach

Adopt Blinter, pinned with hashes, in an offline container, with a bundled config.
It is the only maintained batch linter that runs on Linux,
so it runs in the same Linux job as the other lints and needs no Windows runner.

### Candidates

| Option | Source, licence, upkeep | Fit | Verdict |
| --- | --- | --- | --- |
| [Blinter](https://pypi.org/project/Blinter/) | Open source, AGPL-3.0-or-later. Effectively one maintainer; the repository moved from `tboy1337` to the `BatchLang` organisation. Very frequent releases. | Catches LF endings and dead code after an `exit`, and has config and inline ignores. Misses the syntax error of [the trial](#the-trial). | **Adopted.** |
| [BatCodeCheck](https://www.robvanderwoude.com/battech_batcodecheck.php) | Closed source, freeware, a Windows `.exe`, not updated in years | Classic batch checks | Rejected: needs a Windows runner, and its code cannot be read. |
| A custom check, such as a grep for a trailing `\` | Ours | The failures already seen, and nothing else | Rejected: [plan 126](../126-shared-bat-launcher/plan.md)'s template check already catches the launchers' drift. |

All are free.

### The design trial

Blinter 1.1.73 in `python:3.12-alpine`, run over the launcher and the shared body as plan 126 designs them:

| Rule | Where | What it is | Handled by |
| --- | --- | --- | --- |
| E045, `pause` takes no arguments | `pause > nul`, 4 times | A false positive: the space before `nul` reads as an argument. `pause >nul` passes. | Plan 126 writes `pause >nul`. |
| E006, undefined variable | `%BASH%` in the body | `_find-bash.bat` sets it, and `--follow-calls` does not see that | An inline ignore in the body |
| W033, ambiguous `call` | `call "%launch_body%"` | The path is a variable holding `.bat` | An inline ignore in the template |
| SEC014, unescaped input | `%*`, in both | Passing the arguments on is the launcher's job | An inline ignore in both |
| W028, `.bat` and `.cmd` differ | every `set` | Holds only for a choice between `.bat` and `.cmd`, and the launchers stay `.bat` | Disabled |
| S007, use `.cmd` | every file | The same choice | Disabled |
| S008, missing comments | the template's `if` block | Asks for a comment on what code does; comments here say why | Disabled |
| S020, long line | the template's `rem` line | A real finding at the default 100 columns | Kept, at 120 columns, the repository's cap |

The inline ignores sit in plan 126's template and body, which are written to pass:
its [launcher](../126-shared-bat-launcher/plan.md#the-launcher) and
[body](../126-shared-bat-launcher/plan.md#the-shared-body) carry them,
so this plan never renders the launchers again.

## Design

### The run

```mermaid
flowchart LR
    caller[An agent, the user or a CI job] --> runner[blinter.sh]
    runner -->|git ls-files| tracked[Tracked .bat and .cmd]
    runner -->|ensure_docker_image build| image[common-automation/blinter image]
    runner -->|docker run, no network, read-only| linter[blinter, once per file]
```

`.github/actions/blinter/blinter.sh` is the one entry point, as `yamllint.sh` is for yamllint.

- It lists `git ls-files -- '*.bat' '*.cmd'` in the current directory; outside a work tree it is an error.
- A tracked file missing from the work tree is skipped.
- No tracked batch file is a `::notice::` and exit 0, with no image built and no container started.
- One container runs Blinter once per file, since its command line takes one path,
  and exits 1 when any run found something.
- Each run passes `--fail-on style`, so every finding the config leaves on fails.

### The config

`.github/actions/blinter/blinter.ini`, mounted read-only at `/action`:

```ini
[general]
max_line_length = 120

[rules]
disabled_rules = S007, W028, S008
```

A `blinter.ini` at the repository's root wins, as a consumer's `.yamllint` does for yamllint,
so a repository can tighten or relax the bar.
A rule is disabled only when it never fits a batch file of these repositories;
a rule that misfires on one line takes a `REM LINT:IGNORE <code>` line above it,
so it still runs everywhere else.

### The image

`common-automation/blinter:<tag>`, built from a Dockerfile in the action folder through `ensure_docker_image … build`.

- **Base**: `python:3.12-alpine`, yamllint's base, so the two images share their base layers.
- **Packages**: `requirements.in` pins `Blinter==1.1.73`.
  `requirements.txt` is compiled from it with `pip-compile --generate-hashes`,
  pinning Blinter and `charset-normalizer`, its one dependency,
  with the hash of every wheel each release ships.
  `charset-normalizer` ships a wheel per platform, so one hash alone would fail on another machine.
- **Install**: `pip install --no-cache-dir --require-hashes --only-binary :all: -r requirements.txt`.
  Wheels only, so no package's build script runs; a hash mismatch fails the build.
- **Tag**: `<Blinter version>-<hash>`,
  the hash being the first 12 hex digits of a SHA-256 over the Dockerfile and `requirements.txt`,
  so a change to either builds anew and an unchanged image costs one `docker image inspect`.
- **Bumps**: Dependabot's `pip` ecosystem, one entry for `/.github/actions/blinter`, weekly,
  with `cooldown: default-days: 14`, so a pin is a release at least two weeks old.
  Its pull request runs the gate against the new image.
- **Where the pin lives**: `requirements.txt`, not `versions.env`, which cannot hold a hash per wheel.
  `versions.env`'s header names it,
  and the action's README holds the compile command for a bump by hand.

### Where it runs

- **CI:** a `blinter` step in the `batch` job of plan 126's
  [`ci-batch.yml`](../126-shared-bat-launcher/plan.md#the-workflow), after the template check.
  This plan's steps follow plan 126's, since they need that workflow.
- **Locally:** a `blinter` check in the lint half, `_run-lint-yaml-and-bash.sh`.

### Runtime

| Run | Cost | Why |
| --- | --- | --- |
| First build | about 20 s, once per pin | Two wheels from PyPI. |
| A run with the image cached | 1 to 2 s | One container start; each file lints in milliseconds. |
| A repository with no batch file | under 1 s | `git ls-files` only. |

### Security

- The repository and the action folder are mounted read-only,
  and the container runs with `--read-only` and `--network none`,
  so a compromised package can neither change the checkout nor send anything out.
- Every wheel is checked against its hash, and no source build runs.
- The 14-day cooldown and a reviewed pull request stand between a new release and the gate.
  That matters here: one maintainer, frequent releases, and a repository that changed owner.
- AGPL-3.0: the image runs Blinter unmodified and is built where it runs, never published,
  so it distributes nothing that would oblige a source offer.
