# Plan: reusable bash retry primitive

See [problem.md](problem.md) for context, locked decisions, and the
off-the-shelf survey.

## Index

- [Step 1 - Scaffolding](#step-1---scaffolding)
- [Step 2 - Primitive core: budget enforcement](#step-2---primitive-core-budget-enforcement)
- [Step 3 - Backoff strategy: exponential with jitter](#step-3---backoff-strategy-exponential-with-jitter)
- [Step 4 - Classifier strategy: pluggable transient detection](#step-4---classifier-strategy-pluggable-transient-detection)
- [Step 5 - Default transient classifiers (docker, network, HTTP 5xx)](#step-5---default-transient-classifiers-docker-network-http-5xx)
- [Step 6 - Composite action wrapper](#step-6---composite-action-wrapper)
- [Step 7 - Migrate ansible-lint](#step-7---migrate-ansible-lint)
- [Step 8 - Migrate yamllint](#step-8---migrate-yamllint)
- [Step 9 - Migrate actionlint](#step-9---migrate-actionlint)
- [Step 10 - Migrate action-validator](#step-10---migrate-action-validator)

The primitive is built incrementally across steps 2-5 so each
commit ships a working version with one more axis of configurability
than the last. Steps 7-10 are deliberately separate per-action
migrations so a regression in one is bisectable. README updates are
folded into each step rather than batched at the end - every commit
ships the docs for the surface it introduces.

---

## Step 1 - Scaffolding

**Reason:** Land the directory layout and the empty surfaces every
subsequent step writes into, with CI green from commit 1. No
behaviour; presence-only commit.

**Files**

- `scripts/lib/.gitkeep` (new) - establishes the `lib/` subdir under `scripts/` for sourced helpers. Mirrors the `scripts/`-flat convention; the `lib/` subdir is new and exists only to separate sourced primitives from invokeable scripts.
- `.github/actions/retry/.gitkeep` (new) - establishes the composite-action dir; populated in step 6.
- `Tests/actions/retry/.gitkeep` (new) - test fixture dir for the composite, populated in step 6.

**Behaviour**

File presence only. The shared CI gate (yamllint / actionlint /
shellcheck / bats) auto-skips empty surfaces.

**Tests**

The first CI run is the test - any finding against the gitkeeps is
fixed in-line during this step. No new bats / pester.

**README update**

None - scaffold-only commit with no public surface. Subsequent
steps add the relevant subsections as the surfaces land.

```mermaid
flowchart LR
    R[repo root] --> S[scripts/lib/.gitkeep]
    R --> A[.github/actions/retry/.gitkeep]
    R --> T[Tests/actions/retry/.gitkeep]
```

---

## Step 2 - Primitive core: budget enforcement

**Reason:** Smallest viable retry. A working `retry_command` that
retries any non-zero exit with a fixed 1 s sleep, capped by
`RETRY_MAX_ATTEMPTS` and `RETRY_MAX_SECONDS`. Backoff and classifier
are added in steps 3 and 4 - this step proves the budget contract
and the output-passthrough contract in isolation.

**Files**

- `scripts/lib/retry.sh` (new) - sourced helper exposing one function:
  `retry_command <op-name> -- <command...>`. Reads `RETRY_MAX_ATTEMPTS`
  (default `5`) and `RETRY_MAX_SECONDS` (default `300`) from env.
  Always retries on non-zero exit; fixed 1 s sleep between attempts.
- `scripts/lib/retry.bats` (new) - bats suite for the primitive.

**Behaviour (retry_command)**

1. Parse args: `<op-name>` (required, for diagnostic prefixing), then `--`, then the command and its args.
2. Compute deadline: `start_seconds + RETRY_MAX_SECONDS`.
3. Loop:
   1. Increment attempt counter (start at 1).
   2. Run the command, inheriting stdin/stdout/stderr from the caller (no buffering).
   3. If exit 0 → return 0.
   4. If `attempt >= RETRY_MAX_ATTEMPTS` → print `retry: <op-name> exhausted attempts (N)` to stderr, return last exit code.
   5. If `now >= deadline` → print `retry: <op-name> exhausted seconds (S)` to stderr, return last exit code.
   6. Print `retry: <op-name> attempt N failed (exit C), retrying in 1s` to stderr; `sleep 1`.

**Tests (bats)**

- Command that exits 0 on first attempt → primitive returns 0, no retry diagnostic printed.
- Command that exits non-zero N-1 times then 0 → primitive returns 0; stderr names the op N-1 times.
- Command that always exits non-zero → primitive returns the same exit code; diagnostic mentions "exhausted attempts".
- `RETRY_MAX_ATTEMPTS=1` → no retry happens; first non-zero exit propagates immediately.
- `RETRY_MAX_SECONDS=0` → no retry happens (deadline elapses immediately).
- Output preservation: command's stdout reaches caller verbatim; stderr is preserved; only primitive diagnostics carry the `retry:` prefix and go to stderr.
- Argument parsing: missing `<op-name>` → usage error (exit 2); missing `--` separator → usage error (exit 2).

**README update**

- `README.md` (modified) - add a new top-level "Retry primitive" subsection placed under the existing scripts / actions overview. Documents the `retry_command <op> -- <cmd...>` signature, `RETRY_MAX_ATTEMPTS` / `RETRY_MAX_SECONDS` env vars and their defaults, the fixed 1 s sleep, and a one-line usage example sourcing `scripts/lib/retry.sh`. The subsection grows in steps 3, 4, 5, 6 as backoff / classifiers / composite land.
- `scripts/lib/README.md` (new) - directory-purpose stub: sourced helpers, never invoked directly. Lists `retry.sh` as the first entry.

```mermaid
flowchart TD
    A[retry_command op -- cmd args] --> B[parse + deadline]
    B --> C{run cmd}
    C -- exit 0 --> Z[return 0]
    C -- exit non-zero --> D{attempts left and time left?}
    D -- no --> X[stderr: exhausted, return last exit]
    D -- yes --> E[stderr: attempt N failed]
    E --> F[sleep 1]
    F --> C
```

---

## Step 3 - Backoff strategy: exponential with jitter

**Reason:** Fixed 1 s sleeps cause thundering herd during a real
incident (every consumer's retries land at the same offsets).
Exponential backoff with jitter is the industry baseline (AWS SDK,
Google SRE book) - it spreads the retries across time without losing
the convergence guarantee. Configurable so different operations can
tune.

**Files**

- `scripts/lib/retry.sh` (modified) - replace the fixed 1 s sleep with a backoff function.
- `scripts/lib/retry.bats` (modified) - add backoff cases.

**Behaviour**

- New env vars (all optional):
  - `RETRY_BACKOFF_INITIAL_SECONDS` (default `2`)
  - `RETRY_BACKOFF_MAX_SECONDS` (default `60`)
  - `RETRY_BACKOFF_MULTIPLIER` (default `2`)
  - `RETRY_BACKOFF_JITTER_RATIO` (default `0.3`, i.e. ±30% jitter)
- For attempt N (1-indexed), the unjittered interval is
  `min(INITIAL * MULTIPLIER^(N-1), MAX)`.
- Apply jitter: multiply by `1 + uniform(-JITTER_RATIO, +JITTER_RATIO)`.
- Cap so the sleep does not push past `RETRY_MAX_SECONDS` (no point waiting longer than the budget allows).

**Tests (bats)**

- Defaults: attempt 2 sleeps within `[2 * (1 - 0.3), 2 * (1 + 0.3)] = [1.4, 2.6]` s. Attempt 3 within `[4 * 0.7, 4 * 1.3] = [2.8, 5.2]` s. Sampling enforced via a deterministic-seed override (`RETRY_BACKOFF_JITTER_SEED` for tests).
- `RETRY_BACKOFF_MAX_SECONDS=5` clamps long attempts to 5 s.
- `RETRY_BACKOFF_JITTER_RATIO=0` gives deterministic exponential (no jitter).
- Backoff that would push past the deadline is shortened to the remaining time.
- Step-2 cases still pass (the contract for budget enforcement and output preservation is unchanged).

**README update**

- `README.md` "Retry primitive" subsection - replace the "fixed 1 s sleep" sentence with a Backoff paragraph documenting the four `RETRY_BACKOFF_*` env vars, their defaults, the unjittered formula, and the deadline-cap rule. Mention that exponential-with-jitter is the AWS / Google-SRE baseline so readers know why it's the default.

```mermaid
flowchart LR
    N[attempt N] --> I[initial * mult^N-1]
    I --> M[cap at MAX]
    M --> J[apply ±jitter]
    J --> D[cap at remaining deadline]
    D --> S[sleep]
```

---

## Step 4 - Classifier strategy: pluggable transient detection

**Reason:** Today the primitive retries any non-zero exit. That
hides real bugs - a syntax error or 404 should propagate
immediately, not stall for the full budget. Pluggable classifiers
inspect exit code + captured stdout / stderr and decide retriable
vs permanent.

**Files**

- `scripts/lib/retry.sh` (modified) - call a classifier function before deciding to retry.
- `scripts/lib/retry.bats` (modified) - cases for classifier accept / reject.

**Behaviour**

- New env var: `RETRY_CLASSIFIERS` - colon-separated list of classifier function names. Each is a shell function `<name>_classify` that receives the captured exit code (`$1`), stdout file path (`$2`), and stderr file path (`$3`) and exits 0 if the failure is retriable, non-zero if permanent.
- Default value: empty - meaning "always retry" (matches step 2 behaviour). Step 5 ships default classifier names so consumers can opt in via env.
- The primitive captures the command's stdout / stderr to temp files (still tee'd to the inherited fds for live output) so classifiers can inspect them. Files cleaned up between attempts.
- "Retriable" if **any** classifier exits 0. "Permanent" if all classifiers reject (or no classifiers configured AND a strict mode env var is set - this lets consumers opt into strict permanence-by-default in future; default is the lenient "always retriable" so step-2 behaviour persists).
- Diagnostic line names which classifier matched on retry: `retry: <op> attempt N retriable via <classifier>, sleeping Ns`.

**Tests (bats)**

- No classifiers configured → behaviour identical to step 2 (always retries on non-zero).
- One classifier configured, accepts → primitive retries; diagnostic names the classifier.
- One classifier configured, rejects → primitive returns the failure immediately, no retry; diagnostic names which classifier rejected and why (its stderr).
- Two classifiers OR'd: one rejects, one accepts → retries.
- Classifier receives the captured stdout / stderr (case writes a sentinel string to stdout, classifier asserts on it).
- Live output reaches caller while capture is in progress (no swallowing).

**README update**

- `README.md` "Retry primitive" subsection - add a Classifiers paragraph documenting `RETRY_CLASSIFIERS` (colon-separated function names), the `<name>_classify` contract (`$1`=exit, `$2`=stdout path, `$3`=stderr path; exit 0 = retriable), OR-semantics across multiple classifiers, the empty-default "always retry" behaviour, and that step 5 will ship the first batch of built-in classifier names.

```mermaid
flowchart TD
    A[cmd fails exit C] --> B[capture stdout/stderr files]
    B --> C{any classifier accepts?}
    C -- yes --> D[backoff + sleep + retry]
    C -- no --> E[return exit C immediately]
```

---

## Step 5 - Default transient classifiers (docker, network, HTTP 5xx)

**Reason:** Ship the three classifiers that cover today's known pain
so consumers do not have to author their own to get value from the
primitive. The four lint actions migrate against these in steps 7-10.

**Files**

- `scripts/lib/retry.sh` (modified) - define `classify_docker_registry`, `classify_network`, `classify_http_5xx` functions; document the patterns they match.
- `scripts/lib/retry.bats` (modified) - per-classifier cases.

**Behaviour**

Each classifier is a `*_classify` function matching its documented
patterns against the captured stderr / stdout. All patterns are case-
insensitive grep.

- `classify_docker_registry` - matches Docker / OCI registry transients:
  - `dial tcp .*: i/o timeout`
  - `dial tcp .*: connection refused`
  - `failed to do request: Head .* dial tcp`
  - `received unexpected HTTP status: 5[0-9][0-9]` (from docker pulls)
  - `TLS handshake timeout`
  - `unexpected EOF`
- `classify_network` - generic network transients:
  - `Temporary failure in name resolution`
  - `Could not resolve host`
  - `Connection timed out`
  - `Connection reset by peer`
  - `Network is unreachable`
- `classify_http_5xx` - HTTP 5xx text in tool output:
  - `HTTP/[0-9.]* 5[0-9][0-9]`
  - `Server Error: 5[0-9][0-9]`

**Tests (bats)**

Per classifier:

- Each documented pattern, presented as captured stderr → classifier accepts (exit 0).
- A clearly-permanent message (e.g. `Permission denied`, `404 Not Found`, `syntax error`) → classifier rejects (exit non-zero).
- Empty input → classifier rejects.
- End-to-end: `RETRY_CLASSIFIERS=classify_docker_registry` against a stub command that prints a docker-registry timeout and exits non-zero → primitive retries; against a stub printing `404 Not Found` → primitive returns immediately.

**README update**

- `README.md` "Retry primitive" subsection - add a table of the three built-in classifiers (`classify_docker_registry`, `classify_network`, `classify_http_5xx`) with the patterns each matches, plus a one-line recommended-default value for `RETRY_CLASSIFIERS` covering dockerised-action use (`classify_docker_registry:classify_network:classify_http_5xx`). Note that lint actions in this repo will adopt this default in steps 7-10.

```mermaid
flowchart LR
    subgraph defaults [Default classifiers]
        DR[classify_docker_registry]
        NW[classify_network]
        H5[classify_http_5xx]
    end
    DR -.matches.-> P1[dial tcp i/o timeout, etc.]
    NW -.matches.-> P2[name resolution, conn reset, etc.]
    H5 -.matches.-> P3[HTTP 5xx in output]
```

---

## Step 6 - Composite action wrapper

**Reason:** Workflows that want retry semantics in YAML (rather than
in a `run:` block sourcing the primitive directly) need an action
target. The composite is a thin pass-through to the primitive,
exposing only the minimal input surface locked in problem.md.

**Files**

- `.github/actions/retry/action.yml` (new) - composite action with three inputs (`command`, `max_attempts`, `transient_patterns`) and a single `runs:` step that sources `retry.sh` and invokes `retry_command`.
- `Tests/actions/retry/retry.bats` (new) - end-to-end via the composite's underlying bash, exercising input → primitive wiring.

**Behaviour (action.yml)**

- Inputs:
  - `command` (required) - bash command string passed verbatim to `retry_command`.
  - `max_attempts` (optional, default `5`) - exported as `RETRY_MAX_ATTEMPTS`.
  - `transient_patterns` (optional, default `classify_docker_registry:classify_network:classify_http_5xx`) - exported as `RETRY_CLASSIFIERS`.
- The bash entry resolves the primitive per the locked sourcing pattern: env-var primary (`GHCOMMON_REPO_ROOT="${{ github.action_path }}/../../.."`), relative-path fallback for direct invocation (`${SCRIPT_DIR}/../../..`).
- Invokes `retry_command "$command" -- bash -lc "$command"`. The `bash -lc` lets the input be a normal one-line shell expression with pipes and redirects.

**Tests (bats)**

Composite is bash under the hood, so the suite drives the same bash
entry point with seeded inputs:

- Command succeeds first try → action exits 0.
- Command transient-fails twice then succeeds → action exits 0; primitive's diagnostic confirms 2 retries.
- Command permanently fails → action exits non-zero with the command's exit code.
- Default `transient_patterns` cover docker registry timeouts (one positive case via the seeded stub).
- Custom `transient_patterns` overrides the defaults entirely (workflow opts in).
- Missing `command` input → action errors at composite-action validation.

**README update**

- `.github/actions/retry/README.md` (new) - composite action's own README: input contract (the three inputs with defaults), one usage example as a workflow step (`uses: ./.github/actions/retry`), a "for power users" pointer to sourcing `scripts/lib/retry.sh` directly when the minimal input surface is too coarse, and a link back to the top-level "Retry primitive" subsection. Includes the env-var-primary / relative-fallback sourcing pattern note for in-repo callers.
- `README.md` "Retry primitive" subsection - add a Composite action paragraph linking the new action's README and showing a one-line workflow snippet so consumers can find it.

```mermaid
flowchart LR
    W[workflow uses: ./retry] --> Y[action.yml]
    Y -- exports env --> B[bash entry]
    B -- resolves --> L[scripts/lib/retry.sh]
    L --> R[retry_command]
```

---

## Step 7 - Migrate ansible-lint

**Reason:** First migration. The recent CI failure on
Infrastructure-VM-Ansible was this action. Wrapping `docker build`
in the primitive turns the next registry blip into a recovered run
instead of a red one.

**Files**

- `.github/actions/ansible-lint/ansible-lint.sh` (modified) - source `retry.sh` via the locked env-var-primary / relative-fallback pattern; wrap the `docker build` invocation in `retry_command "ansible-lint docker build" -- docker build ...`.
- `.github/actions/ansible-lint/ansible-lint.bats` (modified, if it exists; create otherwise) - cases for the retry path.

**Behaviour**

- Default classifiers active: `classify_docker_registry:classify_network:classify_http_5xx`.
- `docker run` (the lint invocation itself) is NOT wrapped. Lint failures are real failures, not transient.
- All other behaviour (auto-skip, config resolution, image tag pinning) unchanged.

**Tests (bats)**

- Stubbed `docker build` succeeds first try → action exits 0; primitive never retries.
- Stubbed `docker build` emits a `dial tcp ... i/o timeout` on first call and succeeds on second → action exits 0; primitive's diagnostic confirms one retry.
- Stubbed `docker build` emits `Permission denied` → action exits non-zero immediately (classifier rejects).

**README update**

- `.github/actions/ansible-lint/README.md` (modified, or new if absent) - add a one-line note that the action's `docker build` step is wrapped by [the retry primitive](../retry/README.md) with the default classifiers, plus a one-sentence explanation of what that means for the consumer (transient registry failures recover automatically; lint failures still fail fast).

```mermaid
flowchart TD
    A[ansible-lint.sh] --> R{retry_command}
    R -- attempt 1 --> B[docker build]
    B -- transient err --> R
    R -- attempt 2 --> B
    B -- success --> D[docker run ansible-lint]
```

---

## Step 8 - Migrate yamllint

**Reason:** Same pattern as step 7, applied to yamllint. Separate
step so a regression in either is bisectable.

**Files**

- `.github/actions/yamllint/yamllint.sh` (modified) - wrap `docker build` in `retry_command "yamllint docker build" -- ...`.
- `.github/actions/yamllint/yamllint.bats` (modified or new) - mirror cases from step 7.

**Behaviour, Tests** - mirror step 7 with yamllint's op-name.

**README update**

- `.github/actions/yamllint/README.md` - mirror the one-line retry note added in step 7 for ansible-lint.

```mermaid
flowchart LR
    Y[yamllint.sh] --> R[retry_command]
    R --> B[docker build]
    B --> Z[docker run yamllint]
```

---

## Step 9 - Migrate actionlint

**Reason:** Same pattern. Separate step for bisectability.

**Files**

- `.github/actions/actionlint/actionlint.sh` (modified) - wrap `docker build` in `retry_command "actionlint docker build" -- ...`.
- `.github/actions/actionlint/actionlint.bats` (modified or new) - mirror cases.

**Behaviour, Tests** - mirror step 7.

**README update**

- `.github/actions/actionlint/README.md` - mirror the one-line retry note added in step 7.

```mermaid
flowchart LR
    A[actionlint.sh] --> R[retry_command]
    R --> B[docker build]
    B --> Z[docker run actionlint]
```

---

## Step 10 - Migrate action-validator

**Reason:** Last of the four. Separate step.

**Files**

- `.github/actions/action-validator/action-validator.sh` (modified) - wrap `docker build` in `retry_command "action-validator docker build" -- ...`.
- `.github/actions/action-validator/action-validator.bats` (modified or new) - mirror cases.

**Behaviour, Tests** - mirror step 7.

**README update**

- `.github/actions/action-validator/README.md` - mirror the one-line retry note added in step 7. With this step, all four lint actions document their retry behaviour and the top-level "Retry primitive" subsection (created in step 2, grown across steps 3-6) is complete - no terminal documentation step needed.

```mermaid
flowchart LR
    V[action-validator.sh] --> R[retry_command]
    R --> B[docker build]
    B --> Z[docker run action-validator]
```
