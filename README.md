# GitHub-Common

Shared, tech-agnostic GitHub Actions composite actions and reusable workflows.

Lives outside any single language ecosystem so it can be consumed by
PowerShell, .NET, and future stacks without dragging tooling along.

## Index

- [Actions](#actions)
- [Local development](#local-development)
- [Consuming](#consuming)
- [Layout](#layout)

## Actions

| Action                                  | Purpose                                                            |
|-----------------------------------------|--------------------------------------------------------------------|
| `actions/assert-secret/`                | Fails a job with a clear message when a required secret is empty. |
| `actions/build-ssh-test-image/`         | Builds the SSH target Docker image used by integration tests.     |

## Local development

Shell logic is extracted into `*.sh` files alongside each action and unit-
tested with [bats-core](https://github.com/bats-core/bats-core). Static
analysis is `shellcheck`.

Run the test suite from the repo root:

```bash
./scripts/run-tests.sh
```

`scripts/run-tests.sh` uses native `bats` if installed, otherwise falls
back to Docker (`bats/bats:1.11.0`, same image CI uses). Run it before
pushing to catch failures locally. Windows users can double-click
`scripts/run-tests.bat` for the same result.

## Consuming

Reference from another repo's workflow:

```yaml
- uses: VitaliiAndreev/GitHub-Common/actions/assert-secret@v1
  with:
    value: ${{ secrets.PSGALLERY_API_KEY }}
    name: PSGALLERY_API_KEY
```

Use `@v1` for the stable tag once published; pin to `@master` during
iteration, or to a SHA for maximum reproducibility.

## Layout

```
GitHub-Common/
├── .github/workflows/ci.yml         # shellcheck + bats on PR/push
├── actions/
│   ├── assert-secret/
│   │   ├── action.yml               # composite, invokes the .sh
│   │   ├── assert-secret.sh         # logic
│   │   └── assert-secret.bats       # unit tests
│   └── build-ssh-test-image/
│       ├── action.yml               # composite (Docker buildx + cache)
│       └── Dockerfile               # Ubuntu 24.04 + openssh-server
├── scripts/
│   ├── run-tests.sh                 # local bats runner (native or Docker)
│   └── run-tests.bat                # double-clickable Windows launcher
└── README.md
```
