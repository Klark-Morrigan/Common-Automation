# Batch File Lint

Issue: [#127](https://github.com/Klark-Morrigan/Common-Automation/issues/127)

- [Problem](#problem)
  - [What a reader misses](#what-a-reader-misses)
  - [The trial](#the-trial)
  - [What it must be](#what-it-must-be)

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

- **Pinned**: one exact version, installed with its hash, beside the other tool pins in `.github/lib/versions.env`.
- **Contained**: it runs in a container with no network, as the other dockerised linters do,
  so the package never runs on the host.
- **Quiet**: a shared config turns off the rules that do not fit a launcher,
  so a finding means something to fix.
- **Same everywhere**: one helper runs it for an agent, for the user and in CI, from the lint half.
- **Skips cleanly**: a repository with no batch files passes without starting the container.
- **Cheap**: a run over a repository's batch files stays within a few seconds once the image is built.
