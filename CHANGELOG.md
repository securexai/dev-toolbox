# Changelog

All notable changes to dev-toolbox are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial fork from `scripts/.toolbox/`.
- `Containerfile` builds `localhost/dev-toolbox:fedora-43` with uv, ruff,
  pre-commit, betterleaks, pnpm, commitlint, markdownlint-cli2, shellcheck,
  and shfmt baked in.
- Three `$HOME`-leak fixes: `UV_TOOL_DIR`, `UV_TOOL_BIN_DIR`,
  `PRE_COMMIT_HOME` ENVs point all post-build tool installs and pre-commit
  caches into `/opt/`.
- `/srv/work/` workspace root inside the image (container-local, not
  bind-mounted from the host).
- `setup.sh` builds the image and creates the `dev` toolbox container
  idempotently.
- `bootstrap-repo.sh` drops six enforcement templates into a target git
  repo and wires pre-commit. Runs inside the toolbox.
- Six templates: `.pre-commit-config.yaml`, `.betterleaks.toml`,
  `commitlint.config.js`, `.markdownlint-cli2.yaml`, `.editorconfig`,
  `.devcontainer/devcontainer.json`.
- VS Code Dev Containers integration documented in [README.md](README.md).

### Changed

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
