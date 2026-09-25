# Changelog

All notable changes to dev-toolbox are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- End-user guide for choosing and using Toolbox profiles, project storage,
  Python and infrastructure workflows, verification and safe replacement.

- Three local Toolbox profiles: base, Python and infrastructure, with
  profile-aware setup, parent image tracking and runtime verification.

- Optional Fedora 44 Kinoite host pnpm installer/uninstaller with a pinned,
  checksum-verified release, Toolbx-aware shell setup, explicit legacy adoption,
  recovery backups, and isolated lifecycle tests. See [usage](docs/host-pnpm.md).

- `scripts/check-precommit-parity.sh` plus a `local` pre-commit hook that
  asserts the dogfood `.pre-commit-config.yaml` and the downstream
  `templates/.pre-commit-config.yaml` share the same `(repo, rev)` pin
  set. Fires whenever either YAML is staged; prints a unified diff and
  exits non-zero on drift. Pure-bash extraction (no `yq` / `awk`
  dependency) so it runs anywhere the toolbox does.
- Initial fork from `scripts/.toolbox/`.
- `Containerfile` builds `localhost/dev-toolbox:fedora-43` with uv, ruff,
  pre-commit, betterleaks, pnpm, commitlint, markdownlint-cli2, shellcheck,
  and shfmt baked in.
- Three `$HOME`-leak fixes: `UV_TOOL_DIR`, `UV_TOOL_BIN_DIR`,
  `PRE_COMMIT_HOME` ENVs point all post-build tool installs and pre-commit
  caches into `/opt/`.
- `setup.sh` builds the image and creates the `dev` toolbox container
  idempotently.
- `bootstrap-repo.sh` drops six enforcement templates into a target git
  repo and wires pre-commit. Runs inside the toolbox.
- Six templates: `.pre-commit-config.yaml`, `.betterleaks.toml`,
  `commitlint.config.js`, `.markdownlint-cli2.yaml`, `.editorconfig`,
  `.devcontainer/devcontainer.json`.
- VS Code Dev Containers integration documented in [README.md](README.md).

### Changed

- The base and derived profiles now use Fedora 44.

- Shared image globals moved to profile or project ownership. uv and Ruff now
  use signed Fedora RPMs; existing pinned repository hooks remain authoritative.
- Default setup creates `dev-base`; existing `dev` containers are preserved.

- Project workspace guidance now uses `~/code/repos`, which is shared with the
  host and persists after a Toolbox container is removed.

- Expanded the host pnpm guide with command reference, adoption rules, update
  limitations, file ownership, transaction recovery, troubleshooting and validation.

- Documentation: clarified that Bash 5.3+ ships by default on both
  Fedora 43 and 44, matching the existing "Fedora 43 or 44" host-support
  statement in [README.md](README.md) and [INSTALL.md](INSTALL.md).
- Tightened the `azure-ad-client-secret` rule in
  `templates/.betterleaks.toml` to require an assignment context
  (`=` or `:`) before the secret value. The original rule (inherited from
  `scripts/`) matched any 34-40 character token in any `*client_secret*`
  file, including UUIDs and base64 chunks.
- Set `shellcheck` pre-commit severity to the default `warning` instead of
  `--severity=error`. The `scripts/` baseline had error severity as a
  temporary workaround for legacy code; new repos do not need it.

### Removed

- `mise.toml` template. The image bakes the same set of tools that `scripts/`
  pinned via mise. A mise-managed shadow set would either install tools into
  `$HOME` (defeating the disposal goal) or duplicate the baked toolchain.

### Source

Forked from the `scripts/.toolbox/` reference in the internal review repo
on 2026-05-13. That toolbox is amd64-only and targets Fedora 43; same
constraints carry over here.
