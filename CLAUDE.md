# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> This repo follows the template baseline in `~/.claude/CLAUDE.md` (EPCCV
> workflow, conventional commits, pre-commit gates, signing setup, GraphQL
> PR replies). The sections below cover only what is project-specific.

## What this repo is

A pinned Fedora-toolbox container image plus two shell scripts that
materialize enforcement templates into target repositories. The central
design property: **tools and workspace are container-local**. `toolbox rm
dev` (or `podman rm dev`) deletes every tool and every cloned repo while
leaving `$HOME` and the immutable Fedora host filesystem untouched.

There is no application code here — no Python, no test suite to run.
Validation is static: shell linting, markdown linting, secret scanning,
and a code-reviewer pass. End-to-end behaviour is verified by running the
scripts against a sibling `test-bootstrap` repo (see PLAN.md task 7).

## Architecture (three moving parts)

1. **`Containerfile`** — builds `localhost/dev-toolbox:fedora-43`. Pins
   `uv` (0.11.8), `betterleaks` (1.1.2, sha256-verified), and `pnpm`
   (11.0.3, sha256-verified). Installs `ruff`, `commitlint`,
   `markdownlint-cli2` post-`FROM`. Sets three ENVs (`UV_TOOL_DIR`,
   `UV_TOOL_BIN_DIR`, `PRE_COMMIT_HOME`) that route every later
   `uv tool install` and pre-commit hook cache into `/opt/`, never into
   `$HOME`. Creates `/srv/work/` (mode 1777) as the workspace root —
   toolbox does **not** bind-mount `/srv`, so anything written there
   disappears with the container.
2. **`setup.sh`** — host-side. Verifies `podman` + `toolbox` are on PATH,
   builds the image idempotently, creates the `dev` container. Defaults
   `--network=slirp4netns` to dodge a Fedora 43 `passt-selinux` AVC.
3. **`bootstrap-repo.sh`** — toolbox-side. Drops six templates from
   `templates/` into a target git worktree, then runs
   `pre-commit install --install-hooks`. Idempotent (skips existing files
   unless `--force`). Accepts `--target <path>` (defaults to `$PWD`).

The repo also dogfoods its own enforcement: `.pre-commit-config.yaml` at
the root is **distinct from** `templates/.pre-commit-config.yaml`. The
root config excludes `templates/` from secret scanning because the
template files intentionally contain example regex patterns that look
like the secrets they protect against. Do not collapse the two.

## Critical invariants (do not break)

- **`$HOME` cleanliness.** Anything that lands in `~/.local/share/uv/tools`,
  `~/.cache/pre-commit`, or anywhere under `$HOME` from inside the toolbox
  defeats the disposal property. The three ENVs in the Containerfile are
  what enforce this — preserve them and never document a `uv tool install`
  or `pre-commit run` that does not respect them.
- **`/srv/work` is container-local.** Do not add a `workspaceMount` to
  `templates/.devcontainer/devcontainer.json` that bind-mounts the host
  folder; the template intentionally omits that key.
- **Image binary ≠ gate binary.** The pnpm-installed `commitlint` and
  `markdownlint-cli2` in `/usr/local/bin` are for ad-hoc CLI use. The
  pre-commit hooks pin their own versions via `additional_dependencies`
  (commitlint) or `rev:` (markdownlint-cli2). Bumping one side does not
  bump the other — by design.
- **`pre-push` is not in `default_install_hook_types`.** No hook in
  `templates/.pre-commit-config.yaml` targets pre-push, so wiring it
  would materialise a no-op `.git/hooks/pre-push`. Re-add it only when a
  hook with `stages: [pre-push]` lands.
- **amd64-only.** `betterleaks` and `pnpm` release tarballs are amd64-only.
  Adding arm64 requires a Containerfile branch (out of scope per PLAN.md).
- **Bash 5.3+ in scripts.** Both shell scripts include a version guard
  (exit 69) and the strict-mode preamble (`errexit`, `nounset`, `pipefail`,
  `errtrace`, `inherit_errexit`, `nullglob`). The `bash-standards` skill
  is the reference.

## Commonly used commands

These are not application commands — they are how you exercise and
validate the toolbox itself.

| Goal | Command |
| --- | --- |
| Build image + create container (idempotent) | `./setup.sh` |
| Force image rebuild | `REBUILD=1 ./setup.sh` |
| Trace the script | `TRACE=1 ./setup.sh` |
| Enter the toolbox | `toolbox enter dev` |
| Bootstrap a target repo (inside toolbox) | `./bootstrap-repo.sh --target /srv/work/<repo>` |
| Re-bootstrap, overwriting existing files | `./bootstrap-repo.sh --force --target /srv/work/<repo>` |
| Reset the whole dev env | `toolbox rm dev && ./setup.sh` |
| Run the dogfood pre-commit gate | `pre-commit run --all-files` |
| Run a single hook | `pre-commit run shellcheck --all-files` |
| Check pre-commit config parity (root ↔ templates) | `./scripts/check-precommit-parity.sh` |
| Static shell lint (parity with CI gate) | `pnpm dlx shellcheck@4.1.0 setup.sh bootstrap-repo.sh scripts/*.sh` |
| Static markdown lint (parity with CI gate) | `pnpm dlx markdownlint-cli2@0.22.1 --no-globs '**/*.md'` |
| Bump pinned hook revisions | `pre-commit autoupdate` |

There is no test runner. "Testing" a change means:

1. Static validators above exit 0.
2. `pre-commit run --all-files` exits 0.
3. For Containerfile / setup.sh changes: `REBUILD=1 ./setup.sh` succeeds.
4. For bootstrap-repo.sh changes: run it against the sibling
   `test-bootstrap` repo and confirm idempotency + `--force` behaviour.

## Where things live, and what dies when

| Path | Lives in | Survives `toolbox rm dev`? |
| --- | --- | --- |
| `/usr/local/bin/*`, `/opt/uv-tools`, `/opt/pnpm*`, `/opt/pre-commit-cache` | image overlay | No |
| `/srv/work/<repo>` | container overlay (no bind mount) | No |
| `$HOME/.vscode-server`, `$HOME/.ssh`, `$HOME/.gitconfig` | host, bind-mounted | Yes (deliberate) |

If you find yourself wanting to write to `$HOME` from inside the toolbox
for anything other than user identity / VS Code Server, stop and rethink
— that is the bug this repo exists to prevent.

## When editing key files

- **`Containerfile`**: rebuild with `REBUILD=1 ./setup.sh`. If you change
  the `ARG <TOOL>_SHA256` lines, verify the new sha256 against the
  upstream release before pinning. Mode `1777` on `/opt/pre-commit-cache`,
  `/opt/uv-tools`, and `/srv/work` is intentional (host UID is unknown at
  build time) — do not "tighten" it to `0755` without understanding why.
- **`setup.sh` / `bootstrap-repo.sh`**: maintain the version guard, the
  strict-mode preamble, the `on_error` ERR trap, and the sysexits-style
  exit codes (64=usage, 66=missing file/dir, 69=missing dep, 70=internal).
  ShellCheck-clean is the gate.
- **`templates/*`**: changes here affect every downstream repo that runs
  `bootstrap-repo.sh`. Test a template change by re-running the bootstrap
  script with `--force` against `test-bootstrap` and confirming
  `pre-commit run --all-files` still passes there. If you bump a hook
  revision in `templates/.pre-commit-config.yaml`, bump the same line in
  the root `.pre-commit-config.yaml` too — the parity hook will fail the
  commit otherwise.
- **`PLAN.md`**: append to the iteration log when a change responds to a
  code-reviewer finding. The acceptance criteria block is the contract
  for what "A+" means here.
- **`CHANGELOG.md`**: update the `[Unreleased]` section under the
  appropriate Keep-a-Changelog heading on user-visible changes.

## Out of scope (per PLAN.md)

arm64 support, mise-pinned tooling inside the image, a signed-commit
pre-push hook in the template set, and a hosted-registry build/publish
pipeline. The image is built locally on every host by design.
