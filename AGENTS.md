# AGENTS instructions

`network-tools` is a collection of tools for debugging OpenShift cluster network issues.
It contains both debugging scripts and useful tools to get networking information from the cluster.
It also contains scripts to manage JIRA bugs for the networking team.

## Read for the task

- [README.md](README.md): local and OpenShift must-gather usage.
- [docs/contributor.md](docs/contributor.md): project scope, repository structure,
  adding scripts guidelines and script conventions, testing changes.
- [docs/user.md](docs/user.md): command behavior and invocation examples.
- [jira-scripts/README.md](jira-scripts/README.md): JIRA networking bug management tools

## Change conventions

- Use [docs/script-template](docs/script-template) for new Bash commands. Keep
  `description` and help usable without cluster access. Register commands in
  `debug-scripts/network-tools`, or `debug-scripts/local-scripts/local-scripts-map` for local
  tools, and preserve executable permissions.
- Reuse `debug-scripts/utils` and connectivity helpers in
  `debug-scripts/test-networking/common`. Preserve caller-relative paths.
- Follow the contributor guide's `network-tools-*` resource naming and image
  conventions. Preserve cleanup and noninteractive must-gather operation.
- Update command help before running `./docs/generate-docs` from the repository
  root. Do not hand-edit the generated portion of `docs/user.md`.
- For image dependencies, inspect both Dockerfiles and keep package lists sorted.

## Validate the affected area

- Run `bash -n <changed-script>` for Bash edits; check
  `./debug-scripts/network-tools -h` and
  `./debug-scripts/network-tools <command> -h` for registered command changes.
  Inspect standalone scripts before invoking help: some initialize cluster access
  before parsing options.
- For image changes, use `make build-image-network-tools-test` (Podman) and the
  [cluster-testing workflow](docs/contributor.md#testing-scripts). `make` builds
  images; no repository-wide unit-test or lint target is defined.
- `debug-scripts/test-networking` operates on a live cluster and can create or
  delete resources. Use a designated test cluster for behavioral validation;
  syntax/help checks alone do not establish runtime correctness.
- The Jira networking bugs utility's default execution can modify tickets. Validate Python
  changes with syntax checks and mocked clients/fixtures as appropriate; do not
  use a default live run as a smoke test. Never commit `jira_secrets.py`.
- Report checks performed and any unavailable cluster, registry, or tool
  prerequisites. Run `git diff --check` before finishing.

## Keep guidance useful

When implementing or reviewing changes, check relevant linked documentation for
accuracy and update it when behavior or workflows change. Keep this file concise:
retain stable instructions and pointers; put detailed explanations in the docs.
