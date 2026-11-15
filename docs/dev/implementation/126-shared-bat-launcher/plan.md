# Shared Batch Launcher

Issue: [#126](https://github.com/Klark-Morrigan/Common-Automation/issues/126)

- [Problem](#problem)
  - [What happened](#what-happened)
  - [Where the copies are](#where-the-copies-are)
  - [What checks a launcher today](#what-checks-a-launcher-today)
  - [What it must be](#what-it-must-be)

## Problem

Every `.bat` launcher is a hand-copied body, and nothing runs one before someone double-clicks it,
so a broken launcher reaches the user unnoticed.
One shared body, run by a test on every pull request, would leave one place to get right
and catch the mistake when it is written.

### What happened

Two new launchers, `run-tests-bash.bat` and `run-lint-yaml-and-bash.bat`,
had their `_find-bash.bat` line split with a trailing `\`, bash style.
cmd continues a line with `^`, so each split broke the launcher in its own way:

| Split | What cmd does |
| --- | --- |
| `call ... \|\| \` + `exit /b 1` | The `exit /b 1` line runs on its own, so the launcher exits 1 every time, with no message. |
| `call ... \` + `\|\| exit /b 1` | cmd stops with `\|\| was unexpected at this time.`, exit 255. |

Shellcheck, bats and every other lint passed.
The breakage was found by reading the files and then running scratch copies through cmd by hand.

### Where the copies are

130 launchers across 22 repositories repeat the same seven-line body:
resolve Git Bash, silence the script's own pause, run the `.sh` beside it, hold the window, pass the exit code on.
They differ in two things only:

- the script they run;
- the path to `_find-bash.bat`:
  `%~dp0` in Common-Automation,
  `%~dp0..\..\Common-Automation\scripts\` in a consumer, which expects Common-Automation as a sibling checkout.

| Launcher | Copies |
| --- | --- |
| `setup-hooks.bat` | 22 |
| `fix-permissions.bat`, `run-ci-yaml-and-bash.bat`, `run-lint-yaml-and-bash.bat`, `run-tests-bash.bat` | 21 each |
| `fix-whitespace.bat`, `publish-version-tags.bat` | 6 each |
| `run-ci-gradle.bat` | 4 |
| `show-download-counts.bat` | 3 |
| `run-ci-dotnet.bat` | 2 |
| `run-coverage-gradle.bat`, `run-tests-gradle.bat`, `show-log-records-sample.bat` | 1 each |

Their comments have already drifted apart in wording.
A fix to the body, such as the line endings `cmd` needs, has to be made in every copy.

### What checks a launcher today

Nothing does.
The lint half checks bash, YAML, workflows and Markdown, and the bats suites run on Linux, where `cmd` does not exist.
`.gitattributes` now pins `*.bat` to CRLF, which settles line endings but not what a launcher does.

### What it must be

- **One body**: the steps every launcher repeats live in one file in Common-Automation.
  A launcher names its script and hands off, in a line or two.
- **Every copy**: all 130 launchers in the 22 repositories move onto the shared body,
  Common-Automation's own and every consumer's.
- **Reached as today**: a consumer's launcher finds the shared body
  the way it finds `_find-bash.bat` now, through the sibling checkout, so no repository gains a new dependency.
- **Behaviour kept**: a launcher still resolves Git Bash, silences the script's own pause,
  passes its arguments through, holds the window, and exits with the script's code.
- **Tested by running it**: a suite runs each launcher through `cmd` against stubs, a PR gate on a Windows runner.
  It fails on both broken splits above.
- **Same locally**: the suite also runs on a Windows workstation, through the local CI runners.
- **Cheap**: the suite starts no real script and stays within seconds, so a Windows job adds little to a pull request.
