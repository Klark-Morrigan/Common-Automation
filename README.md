# Common-Automation

Shared, tech-agnostic GitHub Actions composite actions and reusable workflows.

Lives outside any single language ecosystem so it can be consumed by
PowerShell, .NET, and future stacks without dragging tooling along.

## Index

- [Actions](#actions)
- [Retry primitive](#retry-primitive)
- [Log records](#log-records)
- [Local development](#local-development)
  - [One-time setup after clone](#one-time-setup-after-clone)
  - [Running checks and tests locally](#running-checks-and-tests-locally)
- [Consuming](#consuming)
- [Layout](#layout)

## Actions

**Linting & validation**

| Action                                          | Purpose                                                           |
|-------------------------------------------------|-------------------------------------------------------------------|
| `.github/actions/shellcheck-bash/`              | Runs strict shellcheck on every *.sh under a given directory.     |
| `.github/actions/actionlint/`                   | Lints GitHub Actions workflows and composite actions via pinned rhysd/actionlint. |
| `.github/actions/action-validator/`             | Schema-validates workflows and composite `action.yml` files via pinned mpalmer/action-validator. |
| `.github/actions/yamllint/`                     | Lints plain YAML (Ansible, dependabot, mkdocs, ...) outside the actionlint / action-validator surface, via pinned yamllint. |
| `.github/actions/shellcheck-hooks/`             | Runs the same strict shellcheck over the extension-less git hooks under a directory (`.githooks/` by default), which the `*.sh` glob cannot reach. |

Ansible-specific linting (playbooks, roles, `ansible.cfg`) is no longer
part of this repo: it lives in Common-Ansible's `ci-ansible.yml` reusable
workflow, which owns the ansible-lint toolchain and its execution model.

**Test infrastructure**

| Action                                          | Purpose                                                           |
|-------------------------------------------------|-------------------------------------------------------------------|
| `.github/actions/test-bats/`                    | Installs bats-core and runs every *.bats suite under a given path. |
| `.github/actions/build-ssh-test-image/`         | Builds the SSH target Docker image used by integration tests.     |

**CI utilities**

| Action                                          | Purpose                                                           |
|-------------------------------------------------|-------------------------------------------------------------------|
| `.github/actions/assert-secret/`                | Fails a job with a clear message when a required secret is empty. |
| `.github/actions/check-sh-executable/`          | Fails a job when any tracked `*.sh` is missing the executable bit. |
| `.github/actions/retry/`                        | Wraps an arbitrary bash command in the [retry primitive](#retry-primitive) with default transient classifiers. |
| `.github/actions/checkout-siblings/`            | Clones repositories beside the caller's checkout, so a build that reaches a neighbour's scripts by relative path finds them. |
| `.github/actions/clean-workspace/`              | Empties `GITHUB_WORKSPACE` at the start of a job on a self-hosted runner, where the previous run's files survive. Refuses any path it cannot identify as a runner workspace. |

**Release**

| Action                                          | Purpose                                                           |
|-------------------------------------------------|-------------------------------------------------------------------|
| `.github/actions/create-github-release/`        | Creates a GitHub Release for a tag, body taken from the matching `CHANGELOG.md` section (Keep a Changelog). Stack-agnostic - any artifact stream (PowerShell module, NuGet, ZIP, ...) reuses it; fails if the version has no changelog section. Optional `files` input (newline-separated) attaches release assets; optional `notes-suffix` appends markdown below the section under a horizontal rule, for release-time context the changelog cannot state. |
| `.github/actions/publish-download-badges/`      | Publishes download-count badges that count only the release assets people download, not the files clients poll. Contract and inputs: its `action.yml`. |

## Retry primitive

`.github/lib/retry.sh` is a sourced helper that wraps any command in
a bounded retry loop, so callers (including the dockerised lint
actions in this repo) don't reimplement the same `until ... sleep ...`
pattern when a transient failure - Docker registry timeout, DNS
blip, HTTP 5xx - flakes a CI run. It lives alongside the other
production sourced helpers (`fix-sh-executable.sh`,
`fix-trailing-whitespace.sh`, `get-*-version.sh`).

Signature:

```bash
# shellcheck source=.github/lib/retry.sh
source "${REPO_ROOT}/.github/lib/retry.sh"
retry_command "docker build" -- docker build -t foo .
```

The first argument is an operation name used in diagnostics. `--`
separates it from the command vector so the wrapped command can
carry arbitrary flags.

Configuration env vars (defaults shown):

| Env var               | Default | Meaning                                              |
|-----------------------|---------|------------------------------------------------------|
| `RETRY_MAX_ATTEMPTS`  | `5`     | Hard cap on attempts including the first try.        |
| `RETRY_MAX_SECONDS`   | `300`   | Wall-clock budget across all attempts.               |

Between attempts the primitive calls a **backoff strategy** to
compute the sleep duration. The strategy is a shell function whose
name is held in `RETRY_BACKOFF_STRATEGY`; the primitive itself only
calls it and caps the returned value to the remaining wall-clock
budget. This indirection means a future caller needing a different
shape (constant / linear / decorrelated jitter) registers a function
and points the env var at it - no edits to the primitive.

Strategy contract:

| `$1`  | Retry index (1 for the first retry after attempt 1 fails). |
| `$2`  | Remaining wall-clock budget in seconds (advisory).         |
| stdout | Sleep duration in seconds (decimals allowed).             |
| exit  | 0 on success; non-zero is a usage error.                   |

The primitive caps the returned value to `$2` automatically, so a
strategy can't sleep past the deadline by accident.

The shipped default is `exponential_jitter_backoff`, which lives
in its own file at
`.github/lib/retry-strategies/exponential-jitter.sh` and is sourced
automatically when `retry.sh` is loaded. The file doubles as the
worked example for consumers writing their own strategies. The
function follows the AWS SDK and Google SRE-book baseline: for
retry index `R`, the unjittered interval is
`min(INITIAL * MULTIPLIER^(R-1), MAX)`; jitter then multiplies by
`1 + uniform(-RATIO, +RATIO)`. Its knobs:

| Env var                          | Default | Meaning                                                  |
|----------------------------------|---------|----------------------------------------------------------|
| `RETRY_BACKOFF_INITIAL_SECONDS`  | `2`     | Base sleep after the first failed attempt.               |
| `RETRY_BACKOFF_MAX_SECONDS`      | `60`    | Cap on the unjittered sleep, applied before jitter.      |
| `RETRY_BACKOFF_MULTIPLIER`       | `2`     | Growth factor per retry index.                           |
| `RETRY_BACKOFF_JITTER_RATIO`     | `0.3`   | Symmetric jitter band (`0.3` = +/-30%). `0` disables.    |

Registering a custom strategy:

```bash
# In a file sourced before retry_command runs:
my_constant_backoff() {
    # $1 = retry index, $2 = remaining seconds (ignored here).
    echo "5.000"
}
export -f my_constant_backoff
export RETRY_BACKOFF_STRATEGY=my_constant_backoff
```

Between the failed attempt and the backoff sleep, the primitive runs
**classifiers** to decide whether the failure is worth retrying at
all. A classifier is a shell function named `<name>_classify`
listed in `RETRY_CLASSIFIERS` (colon-separated). Each is invoked with
the failed attempt's exit code, the path to its captured stdout, and
the path to its captured stderr; it returns 0 to mark the failure
retriable and non-zero to mark it permanent. Default is an empty
list, which preserves the always-retry behaviour described above -
opt in to triage by setting the env var.

Classifier contract:

| `$1`   | Exit code from the failed attempt.                       |
| `$2`   | Path to a file containing the attempt's stdout.          |
| `$3`   | Path to a file containing the attempt's stderr.          |
| exit 0 | Failure is retriable.                                    |
| exit !0 | Failure is permanent (its stderr is surfaced verbatim). |

Multiple classifiers OR: any accept triggers a retry; all reject
makes the primitive return the failed exit code immediately, naming
the last rejector and its stderr in the `retry:` diagnostic so the
reason is visible without re-running. While classifiers are active,
the wrapped command's stdout / stderr are tee'd to capture files for
inspection AND still forwarded to the caller's fds in real time - no
swallowing.

Three default classifiers ship out of the box, each living in its
own file under `.github/lib/retry-classifiers/` and sourced
automatically when `retry.sh` is loaded. All three match
case-insensitively against the captured stdout *and* stderr - which
fd carries the error varies by tool, so scanning both keeps the
classifier from missing real transients.

| Classifier                  | Patterns it accepts as retriable                                                                                                                                                                                                  |
|-----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `classify_docker_registry`  | `dial tcp .*: i/o timeout`, `dial tcp .*: connection refused`, `failed to do request: Head .* dial tcp`, `received unexpected HTTP status: 5[0-9][0-9]`, `TLS handshake timeout`, `unexpected EOF`, `context deadline exceeded`.   |
| `classify_network`          | `Temporary failure in name resolution`, `Could not resolve host`, `Connection timed out`, `Operation timed out` (curl's `--max-time`), `Connection reset by peer`, `Network is unreachable`, `i/o timeout`.                         |
| `classify_http_5xx`         | `HTTP/<version> 5[0-9][0-9]`, `HTTP 5[0-9][0-9]` (gh's form), `Server Error: 5[0-9][0-9]`, `returned error: 5[0-9][0-9]` (curl's `--fail` form). 4xx is deliberately not matched - those are permanent for the caller (RFC 9110 section 15.6).                                           |

`retry.sh` names the two sets the in-repo scripts use:

| Constant                         | Classifiers                                                     | For                                                                                   |
|----------------------------------|-----------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `RETRY_CLASSIFIER_SET_REGISTRY`  | `classify_docker_registry:classify_network:classify_http_5xx`  | A Docker / OCI registry fetch. The lint actions' `docker pull` and `docker build`. The composite action's default. |
| `RETRY_CLASSIFIER_SET_HTTP`      | `classify_network:classify_http_5xx`                            | A web API or git remote, where a bad token or missing repository must fail at once.  |

A script defaults to one without overriding its own caller's choice:

```bash
RETRY_CLASSIFIERS="${RETRY_CLASSIFIERS:-${RETRY_CLASSIFIER_SET_HTTP}}" \
    retry_or_exit "list the releases of ${repository}" gh api "repos/${repository}/releases"
```

`retry_or_exit <op-name> <command...>` is `retry_command` for a step the script cannot go on without.
When every attempt fails it prints `::error::<script>: could not <op-name>.`, through `workflow-commands.sh`, and exits with the command's last code.
In a stage that `run_stage` runs, that error is written as a log record instead (see [Log records](#log-records)).
It is also safe under `set -e`.
A bare `retry_command` call in an errexit script ends the script at the first failed attempt, before any retry.

`retry_or_exit_to_file <op-name> <file> <command...>` writes the command's stdout to a file, truncated on every attempt.
A failed attempt's partial output never sits beside the output of the attempt that succeeded.

Output is passthrough: the wrapped command's stdout / stderr reach
the caller verbatim. Only the primitive's own messages carry the
`retry:` prefix, and they always go to stderr.

### Composite action

For workflows that prefer a YAML target over sourcing the primitive
in a `run:` block, `.github/actions/retry/` is a thin pass-through
exposing three inputs (`command`, `max_attempts`, `transient_patterns`).
The defaults match the recommended dockerised-action set above. See
[`.github/actions/retry/README.md`](.github/actions/retry/README.md)
for the input contract and worked example. One-line usage:

```yaml
- uses: Klark-Morrigan/Common-Automation/.github/actions/retry@v1
  with:
    command: docker build -t example:ci .
```

## Log records

A script's log has two readers, a person at a terminal and the GitHub Actions log,
and each needs it shaped differently.
So a script writes its log as plain records, and a presenter shapes them for one reader.
The script says what each value is; the presenter decides how it looks.

Everything lives under `.github/lib/log-records/`.
`log-record-format.sh` states the line format the writers and the presenters share,
and the roles a value can take.

The writers live in `writers/`, one sourced file each,
and `writers/write-log-records.sh` loads them all.
Every one writes a single line to stderr, leaving stdout to the data a script hands the next one:

| Writer | Writes |
| --- | --- |
| `write_log_message` | one line of text |
| `write_log_table` | opens a table and names its columns |
| `write_log_row` | a row of the open table |
| `write_log_total` | a row that sums a column, shown under a rule after the other rows |
| `write_log_table_end` | closes the open table |
| `write_log_error` | a failure, as one line of text |
| `write_log_notice` | a run's outcome, as one line of text |

`write_log_table` takes the column names alone.
The others take role and text pairs:
a message's pairs make one line, and a row's or total's pairs are one cell each.
A tab or newline inside a text becomes a space, so no value can split a record.

```bash
# shellcheck source=.github/lib/log-records/writers/write-log-records.sh
source "${lib_dir}/log-records/writers/write-log-records.sh"

write_log_message \
    "${LOG_ROLE_PLAIN}" "Reading the releases of " \
    "${LOG_ROLE_ID}" "${repository}" \
    "${LOG_ROLE_PLAIN}" "."
```

The roles are the `LOG_ROLE_*` constants in `log-record-format.sh`.
A role says what a value is, never how it looks.

A log built in a jq pass writes its records in jq, rather than handing each one to the shell.
`writers/build-log-record.jq`'s `build_log_record` builds the same line `write_log_record` writes,
and its `build_log_table` the table record `write_log_table` writes.
`writers/jq-log-record-args.sh` hands the pass every `LOG_RECORD_*` and `LOG_ROLE_*` constant under its own name,
so the pass reads `$ARGS.named.LOG_ROLE_ID` and never spells a role twice:

```bash
# shellcheck source=.github/lib/log-records/writers/jq-log-record-args.sh
source "${lib_dir}/log-records/writers/jq-log-record-args.sh"

jq -r -L "${script_dir}" "${JQ_LOG_RECORD_ARGS[@]}" \
    'include "some-stage"; describe_items($ARGS.named)' < items.json >&2
```

The stage's jq module includes the builder by a search path relative to itself,
`include "build-log-record" { search: "./<path to .github/lib>/log-records/writers" };`,
and calls `build_log_record($format; $format.LOG_RECORD_KIND_ROW; [ $format.LOG_ROLE_ID, .name ])`.

`presenters/present-log-for-terminal.sh` reads a script's stderr on stdin and prints it shaped:

```bash
some-stage.sh 2>&1 >/dev/null | .github/lib/log-records/presenters/present-log-for-terminal.sh
```

It pads each table's columns, right-aligns a column of numbers, and colours each value by its role.
It prints an error record in red and a notice record as a plain line.
Any line that is not a record passes through unchanged,
so a tool's own errors still show and a script can move onto records one line at a time.
Colour follows `colors.sh`: on in a terminal, off when piped, and `NO_COLOR` and `FORCE_COLOR` override it.
`scripts/show-log-records-sample.sh` prints a sample through it, every role included,
to check the colours in a real terminal.

`presenters/present-log-for-github-actions.sh` shapes the same records for the GitHub Actions step log.
Colour is on, since that log renders it although its stream is never a terminal;
`NO_COLOR` still turns it off.
It writes an error or notice record as a plain `::error::` or `::notice::` annotation.
It also guards every value it prints against reading as a workflow command:
a value from outside, such as a release tag, could otherwise stop commands or fake an annotation.
`presenters/resolve-command-guarded-text.sh` says how.

Both presenters run the one loop in `presenters/present-log-records.sh`,
and hand it their own printers for error and notice records.
Tables are held and printed by the files in `presenters/tables/`.

A script that chains stages runs each through `run-stage.sh`'s `run_stage`.
Under GitHub Actions a stage's log sits in a log group named after it,
and its stderr goes through the GitHub Actions presenter.
In a terminal it gets a section heading instead, and its stderr goes through the terminal presenter.
Its stdout is passed on untouched either way.
A failed stage is followed by a line giving its exit status,
since a stage that crashed may have logged nothing.
A presenter that fails is reported as an error, and fails the stage:
the rest of that stage's log went with it.
A chain's own lines reach no stage's presenter,
so the chain writes each through `write-presented-log-record.sh`'s `write_presented_log_record`,
which runs the record writer as a stage, through the presenter `run_stage` would pick.
`presenters/resolve-log-presenter.sh` makes that pick for both,
from `is-running-in-github-actions.sh`.

A chain keeps a secret such as `GH_TOKEN` as a plain shell variable, exported to nothing.
`run_stage --export GH_TOKEN <stage>` exports it to that stage's process alone:
never its presenter, never the stages beside it.
`split-stage-exports.sh` reads the flags for both `run_stage` and `run_stage_through_presenter`.
Inside a stage, `run-gh-with-token.sh`'s `run_gh_with_token` narrows the token further,
to the one `gh` call that needs it.
`run-git-with-token.sh`'s `run_git_with_token` does the same for a git call that reaches GitHub:
the token travels as a header scoped to one repository's URL,
never in a URL or on a command line.
`create-masked-basic-credential.sh` builds that header's credential and masks it in the log.

This narrowing guards against accidental disclosure:
a tool that writes its environment into a log, a crash report, or a request it sends on.
It is not a boundary against a hostile process in the job.
Every step runs as one user, who can read any process's environment,
and on GitHub-hosted runners that user has passwordless sudo.
The token always reaches the step's own shell through `env:`,
the one channel that keeps it out of the script file the runner writes to disk.

`run_stage` runs each stage with `LOG_RECORDS=true`.
There `workflow-commands.sh` writes `exit_with_error`, `log_error` and `log_notice` as error and notice records,
so the presenter shapes them for its reader.
A script outside such a chain, such as a lint action's, writes its annotations itself.
Either way the command goes through `print-workflow-command.sh`, which escapes its text as the runner expects.

## Local development

Production bash (composite-action logic) is extracted into `*.sh` files alongside each action,
and unit-tested with [bats-core](https://github.com/bats-core/bats-core).
Static analysis is `shellcheck` at its strictest setting (`--severity=style --enable=all`).
It runs through the pinned `koalaman/shellcheck` image, in CI and locally alike,
so a runner image moving to a newer Ubuntu cannot change the result.
The version is `SHELLCHECK_VERSION` in `.github/lib/versions.env`.

Runner bash (maintainer-side dev scripts) lives under `scripts/` and
shares the same lint bar.

### One-time setup after clone

```bash
./scripts/setup-hooks.sh
```

Wires the repo-checked-in pre-commit hook (`.githooks/pre-commit`),
which auto-fixes two things about a commit: the executable bit on
`.sh` files, and trailing whitespace in Markdown.
Without this step, files authored on Windows commit as mode 0644 and
CI catches them later - the hook just turns "push, fail, fix,
re-push" into "commit silently succeeds."

Every repo in the family calls the same body,
`.github/lib/run-pre-commit-fixes.sh`,
which owns which fixes a commit gets and in what order;
each repo's own hook holds only what that repo alone knows -
where its sibling checkouts are,
which paths it needs `+x` on,
and which tier it belongs to.
A consuming repo whose Common-Automation checkout is missing says so and
skips the fixes rather than failing:
these are conveniences,
and a hook that aborted would block every commit in a repo that builds
perfectly well.

The whitespace half covers what no formatter reaches.
Every formatter and whitespace gate in the family reads source sets,
so prose is owned by none of them.
Markdown is the type trimmed here,
being the one every repo has whatever it is written in;
a tier with further text types of its own widens the set after sourcing
the engine,
the way a consumer appends its own `+x` pathspecs:

```bash
WHITESPACE_TRIMMED_TYPES+=('*.gradle')
```

That keeps this tier free of any language's vocabulary -
Gradle scripts are the JVM tier's type,
and Common-Java declares them in its own
`.github/lib/trimmed-file-types.sh`.

The engine is `.github/lib/fix-trailing-whitespace.sh`, shared the way
the `+x` one is -
every repo's hook calls `fix_staged_trailing_whitespace`,
and `scripts/fix-whitespace.sh` trims a whole repo,
which is how files that predate the hook get healed,
along with the ones the hook skipped for having unstaged changes.
A path with unstaged changes beside its staged ones is named and left
alone rather than re-staged:
this fix rewrites content, so re-adding such a file would sweep the
author's unstaged hunks into the commit.

### Running checks and tests locally

```bash
./scripts/run-ci-yaml-and-bash.sh
```

`scripts/run-ci-yaml-and-bash.sh` is the orchestrator: the single
"run everything locally" entry point. It runs both the lint half and
the test half against the target repo and reports a combined
pass/fail. It is the local equivalent of the `ci-yaml.yml` +
`ci-bash.yml` workflows, so a green run here means CI should pass too.
Run it before pushing to catch failures locally. Windows users can
double-click `scripts/run-ci-yaml-and-bash.bat` for the same result.

The work is split across three `_`-prefixed building blocks the
orchestrator sources and runs; the underscore marks them as internal
to the runner set rather than entry points. Each can also be invoked
in isolation when you only care about one half:

- `scripts/_run-common.sh` - shared setup: resolves the target repo
  and arms the hold-window pause on double-click exit. Sourced by the
  three entry scripts below rather than run directly.
- `scripts/_run-lint-yaml-and-bash.sh` - the lint half. Runs
  `shellcheck` (production `.github`, runner `scripts/`, git hooks),
  `check-sh-executable`, `actionlint`, `action-validator`, and
  `yamllint`. Each check auto-skips when its surface is absent,
  so a repo with only some of these still passes cleanly. Docker is
  required for the dockerised linters.
- `scripts/_run-tests-bash.sh` - the test half. Runs every `*.bats`
  suite via native `bats` if installed, otherwise the pinned Docker
  image (`bats/bats:1.11.0`, the same image CI uses).

All three honour `COMMON_AUTOMATION_TARGET_REPO`, which points them at
a repo other than this one. That is how consuming repos run the same
lint + bats recipe against themselves: they ship thin shims of the
same names that set the variable and delegate here, so the runner
logic lives in one place.

## Consuming

### Atomic actions

Reference any action directly from another repo's workflow:

```yaml
- uses: Klark-Morrigan/Common-Automation/.github/actions/assert-secret@v1
  with:
    value: ${{ secrets.PSGALLERY_API_KEY }}
    name: PSGALLERY_API_KEY
```

### Reusable workflow: ci-bash

For repos that want the same lint + bats recipe applied to their own
bash, call the `ci-bash.yml` reusable workflow:

```yaml
jobs:
  bash:
    uses: Klark-Morrigan/Common-Automation/.github/workflows/ci-bash.yml@v1
```

No inputs needed by default - the workflow scans the caller's
`.github/actions/` (production) and `scripts/` (runner) directories.
Missing directories are skipped silently, so a repo that has only one
or the other still works without configuration.

Override `bats-version` if you need to pin to a specific bats release.

### Reusable workflow: ci-yaml

For the same lint recipe applied to a repo's GitHub Actions YAML
(workflows + composite `action.yml` files), call the `ci-yaml.yml`
reusable workflow:

```yaml
jobs:
  yaml:
    uses: Klark-Morrigan/Common-Automation/.github/workflows/ci-yaml.yml@v1
```

No inputs - all three underlying composite actions self-resolve
their pinned versions. The workflow runs `actionlint`,
`action-validator`, and `yamllint`. Each underlying surface may be
absent: actionlint and action-validator skip silently when
`.github/workflows/` or `.github/actions/` is empty; yamllint skips
when no plain YAML exists outside those trees. That auto-skip is
what lets a single reusable workflow serve every consumer without
per-repo configuration.

Ansible content is linted separately by Common-Ansible's
`ci-ansible.yml`; consumers with playbooks or roles call that
reusable workflow instead of relying on this one.

### Markdown lint config

`.markdownlint.jsonc` at this repo's root is the family's Markdown
ruleset, and this repo's own. A consuming repo inherits it by placing
one file at its own root rather than restating the rules:

```jsonc
{
    "extends": "../Common-Automation/.markdownlint.jsonc"
}
```

The path resolves relative to the extending file, so it holds for any
repo checked out as a sibling of this one - the same sibling assumption
the Gradle builds and the pre-commit hooks already make. A repo without
that checkout gets a missing-config report from its editor rather than
a silent fallback to different rules.

Editors read it; no action here runs markdownlint, so nothing in it can
fail a build. The two rules it sets are `MD013` (no column cap, because
prose is broken at sentence and clause boundaries) and `MD024` limited
to siblings (because Keep a Changelog repeats `Added` and `Fixed` once
per version section). Both carry their reasoning in the file.

### Pinning

Use `@v1` for the stable tag once published; pin to `@master` during
iteration, or to a SHA for maximum reproducibility.

## Layout

Every action under `.github/actions/<name>/` follows one shape:
`action.yml` (a composite that invokes the script), `<name>.sh` (the logic) and `<name>.bats` (its unit tests).
The tree below lists only what departs from that shape or is not an action.

```plaintext
Common-Automation/
    .github/
        actions/
            action-validator/        + Dockerfile bundling the pinned mpalmer/action-validator binary, README.md
            actionlint/              + README.md (runs the pinned rhysd/actionlint image)
            assert-secret/
            build-ssh-test-image/    action.yml + Dockerfile only (Ubuntu 24.04 + openssh-server)
            check-sh-executable/
            checkout-siblings/
            clean-workspace/
            create-github-release/
            publish-download-badges/ + publish-badge-branch.sh + .bats (the publish stage), its functions
                                     in badge-branch/;
                                     + .integration.bats (the chain with its real helpers, as a dry run);
                                     sourced: release-summary.sh and source-summary.sh (the line formats
                                     the stages hand on), each + .bats + -fixtures.bash (suites only);
                                     action-input-variables.sh (each input's variable, read by the dry
                                     run and held to action.yml by action-inputs.bats);
                                     print-rendered-endpoints.sh (a dry run's figures) + .bats
                badge-branch/        the publish stage's functions, one per file, each + .bats;
                                     push-failure-fixtures.bash (suites only)
                sources/             one script per stage that reads a host, each + .bats;
                                     summarise-release-downloads.jq (that summary's jq passes) and
                                     its .integration.bats (its log through the terminal presenter);
                                     nexus-files-fixtures.bash and release-listing-fixtures.bash
                                     (suites only)
                renderers/           one render-<figure>.sh per badge figure, each + .bats;
                                     sourced: badge-endpoint.sh (the endpoint schema) + .bats
            retry/                   retry-action.sh + .bats, README.md (input contract)
            shellcheck-bash/
            shellcheck-hooks/
            test-bats/               action.yml only (installs bats-core, runs --recursive)
            yamllint/                + Dockerfile, yamllint.config.yml (default ruleset), README.md
        lib/                         sourced shell helpers shared by the actions and scripts
            changelog.sh             Keep a Changelog section parsing
            colors.sh                TTY- and NO_COLOR-gated colouring
            create-masked-basic-credential.sh  a token as git's Basic credential, masked in the log
            describe-git-checkout.sh  one line on a working tree: branch, commit, uncommitted changes
            detect-baked-bats-libs.sh  which bats helper libraries the runner already has
            fix-sh-executable.sh     the +x fix engine (hook and runner reuse it)
            fix-trailing-whitespace.sh  the trim engine, .md by default
            get-<tool>-version.sh    one per tool: the override, else versions.env
            is-running-in-github-actions.sh  a run under GitHub Actions told from any other
            line-endings.sh          strip_carriage_returns, for a native Windows jq's CRLF output
            list-hook-files.sh       the hooks a lint covers: tracked ones only in a work tree, never a machine's own
            log-records/             sourced: log-record-format.sh (the line format and the roles),
                                     resolve-record-kind.sh + .bats
                writers/             one write_log_<kind> per file, each + .bats; write-log-record.sh
                                     (where every writer writes its record) and write-log-records.sh
                                     (loads every writer), each + .bats; build-log-record.jq (the
                                     same record built in jq) and jq-log-record-args.sh (the format
                                     handed to jq), each + .bats
                presenters/          present-log-for-terminal.sh and present-log-for-github-actions.sh
                                     (run, not sourced); present-log-records.sh (the loop both run);
                                     resolve-log-presenter.sh (which one a log's reader gets); one
                                     sourced function per file beside them, each + .bats
                    tables/          holding, measuring and printing a table, one function per file,
                                     each + .bats; table-layout-format.sh (the column gap)
            print-section-heading.sh  the "=== title ===" heading every script's sections take
            print-workflow-command.sh  a GitHub Actions workflow command, its text escaped
            resolve-docker-host-path.sh  the host form of a docker -v path, so Git Bash's /tmp mounts on Windows
            retry.sh                 the retry primitive; sources the two folders below on load
            retry-classifiers/       one <name>_classify per file
            retry-strategies/        one <name>_backoff per file
            run-pre-commit-fixes.sh  the shared hook body: which fixes a commit gets, in what order
            run-gh-with-token.sh     one gh call with GH_TOKEN set for that process alone
            run-git-with-token.sh    one git call sending a token as a header, for one repository URL
            run-shellcheck.sh        shellcheck through its pinned Docker image, never a native install
            run-stage.sh             one stage of a chain: a log group under GitHub Actions, else a
                                     heading; run-stage-through-presenter.sh (stderr through the
                                     presenter for its reader, LOG_RECORDS=true, failures logged)
            split-fields.sh          split_line_fields, which keeps a line's empty fields
            split-stage-exports.sh   a stage call's --export flags: the variables that stage alone gets
            test-helpers/            sourced by bats suites only (color-escapes.bash, command-stub.bash,
                                     counting-stub.bash, crlf-jq.bash, docker-stub.bash,
                                     git-fixtures.bash, path-stub.bash, require-command.bash)
            versions.env             single source of truth for tool versions
            workflow-commands.sh     exit_with_error and log_notice: annotations named after the script
            write-script-annotation.sh  the body behind them: a record under LOG_RECORDS, else the command
            write-presented-log-record.sh  one record already shaped, for a chain's own lines
            write-step-summary-table.sh  appends a Markdown table to the run's page; run, not sourced
        workflows/
            ci-bash.yml              shellcheck, bats and the +x gate; PR, push and workflow_call
            ci-yaml.yml              actionlint and action-validator; PR, push and workflow_call
    .githooks/
        pre-commit                   thin caller: this repo's +x set, then the shared body
    scripts/                         each .sh entry point has a double-clickable .bat launcher
        _find-bash.bat               resolves Git Bash (not WSL) for the launchers
        _hold-window.sh              sourced: keeps the window open on a double-click exit
        _run-common.sh               sourced: resolves the target repo, arms the hold-window pause
        _run-lint-yaml-and-bash.sh   lint half: each action's helper, as its CI job runs it
        _run-tests-bash.sh           test half: every *.bats suite, native or in Docker
        _to-windows-path.sh          sourced cross-repo: WSL to Windows paths for pwsh.exe arguments
        fix-permissions.sh           repo-wide +x heal for tracked .sh and .githooks/
        fix-whitespace.sh            repo-wide trailing-whitespace trim
        log.sh                       sourced cross-repo: timestamped, level-tagged stderr logger
        publish-version-tags.sh      cuts the immutable vX.Y.Z tag and moves the floating vX tag
        run-ci-yaml-and-bash.sh      runs both halves, combined pass/fail
        setup-hooks.sh               one-time: wires up .githooks/
        show-download-counts.sh      a dry run of publish-download-badges from its inputs as flags; needs gh
        show-log-records-sample.sh   a sample log through the terminal presenter, to check its colours by eye
        timing.sh                    sourced cross-repo: nested timing spans as an e2e-timing/v1 JSON tree
    .markdownlint.jsonc              shared Markdown ruleset; consumers "extends" it
    README.md
```
