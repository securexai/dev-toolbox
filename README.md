# dev-toolbox

A pinned Fedora-toolbox container whose tooling **and** workspace are
container-local. `toolbox rm dev` (or `podman rm dev`) deletes every tool and
every repo cloned inside it, leaving the immutable Fedora host filesystem
untouched.

The image bakes uv, ruff, pre-commit, betterleaks, pnpm, commitlint,
markdownlint-cli2, shellcheck, and shfmt into `/usr/local/bin` and `/opt/`.
The workspace lives at `/srv/work/`, which the toolbox runtime does **not**
bind-mount from the host. Three environment variables (`UV_TOOL_DIR`,
`PRE_COMMIT_HOME`, `UV_TOOL_BIN_DIR`) keep post-build `uv tool install`,
pre-commit hook caches, and any later tool installations out of `$HOME`.

The companion `bootstrap-repo.sh` materialises six enforcement templates
(pre-commit, betterleaks, commitlint, markdownlint-cli2, editorconfig,
devcontainer) into any repo cloned under `/srv/work/`.

## When to use this

Use dev-toolbox when **all four** of the following are true:

- The host is Fedora 43 or 44 (Workstation, Silverblue, or Kinoite), and you
  do not want to mutate the host with `dnf` or `rpm-ostree install`.
- You want one container image that pins every linter, formatter, and scanner
  your repos depend on — same versions on every host that pulls the image.
- You want to clone repos into a place that disappears when the container is
  deleted, so "reset my dev env" is a single `toolbox rm` away.
- Your editor is VS Code (with the Dev Containers extension), or you are
  comfortable running an editor inside the toolbox itself (`nvim`, `helix`,
  `emacs -nw`).

If you only need the linter/formatter/scanner suite installed on the **host**
(and you do not need the workspace to be disposable), the lighter-weight
[`repo-bootstrap` skill][repo-bootstrap-skill] is the right tool. dev-toolbox
exists for the case where `repo-bootstrap` is the wrong shape because it
installs into `$HOME`.

[repo-bootstrap-skill]: https://github.com/conpwxp/dotclaude

## Quickstart

One-time per host (outside the toolbox):

```bash
git clone <this-repo> ~/dev-toolbox
~/dev-toolbox/setup.sh           # builds image + creates `dev` container
```

Per repo (inside the toolbox):

```bash
toolbox enter dev
cd /srv/work
git clone <repo-url> myrepo
~/dev-toolbox/bootstrap-repo.sh --target /srv/work/myrepo
pre-commit run --all-files       # warm cache, audit current tree
```

Reset everything to a clean state:

```bash
exit                             # leave the toolbox shell first
toolbox rm dev
~/dev-toolbox/setup.sh           # container is back in ~3 min
```

`toolbox rm` deletes the container's overlay filesystem, including
`/srv/work/myrepo`. The host's `$HOME` is untouched — your dotfiles, git
config, SSH keys, and `~/.vscode-server/` cache are all still there for the
next toolbox.

## VS Code integration

Two supported flows:

### Attach to running container (recommended)

This flow preserves the disposal property — the repo lives inside the
container only.

1. Install the **Dev Containers** extension in VS Code on the host.
2. Add to `settings.json`:

   ```json
   "dev.containers.dockerPath": "podman"
   ```

3. Start the toolbox once (`toolbox enter dev`, then `exit`), so the container
   is running.
4. In VS Code: <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> → **Dev
   Containers: Attach to Running Container...** → pick `dev`.
5. In the new window: **File → Open Folder** → `/srv/work/myrepo`.

VS Code Server installs into `~/.vscode-server/` the first time you attach.
That path is in `$HOME`, which the toolbox bind-mounts from the host, so the
server persists across `toolbox rm` cycles — that is desirable (faster
re-attach next time).

### Dev containers "Reopen in container"

This flow uses the `templates/.devcontainer/devcontainer.json` that
`bootstrap-repo.sh` drops into every target repo. With this flow VS Code
creates a sibling container alongside `dev` for each repo. It **loses** the
disposal property if you add a `workspaceMount` that bind-mounts the host
folder — the template intentionally omits that key.

Pick this flow only when you need per-repo container customisation that the
shared `dev` toolbox cannot provide (different base image, different
extension list, etc.).

## What lives where, and what dies when

| Location | What lives there | Survives `toolbox rm dev`? |
| --- | --- | --- |
| `/usr/local/bin/` (in image) | uv, ruff, pnpm, betterleaks, commitlint, markdownlint-cli2, shellcheck, shfmt | No |
| `/opt/uv-tools/` (in image) | post-build `uv tool install` targets | No |
| `/opt/pnpm-global/` (in image) | pnpm global package store | No |
| `/opt/pre-commit-cache/` (in image) | pre-commit hook environments | No |
| `/srv/work/<repo>/` (in image) | cloned repos | No |
| `$HOME/.vscode-server/` (host) | VS Code Server backend | Yes (deliberate) |
| `$HOME/.ssh/`, `$HOME/.gitconfig` (host) | user identity | Yes (deliberate) |
| Host Fedora root filesystem | rpm-ostree deployment | Untouched (deliberate) |

## What ships in the image

System packages installed via `dnf` (with `install_weak_deps=False` to drop
unneeded `nodejs-npm`, `nodejs-docs`, and `nodejs-full-i18n`):

| Package | Why |
| --- | --- |
| `git` | Version control |
| `gh` | GitHub CLI; satisfies git credential helper when wired |
| `pre-commit` | Pre-commit framework |
| `nodejs` | Runtime for pnpm-installed globals |
| `python3` | Pre-commit hook interpreter |
| `curl`, `ca-certificates` | Installer fetches |
| `jq`, `ripgrep` | Dev utilities |
| `libatomic` | Required by some Node native modules |
| `shellcheck` | Shell linter (also used by the pre-commit hook for CI parity) |
| `shfmt` | Shell formatter |

Pinned binaries (sha256-verified where the upstream publishes a checksum):

| Tool | Pinned version | Install path |
| --- | --- | --- |
| `uv` | `0.11.8` | `/usr/local/bin/uv` |
| `ruff` | latest at image build | `/opt/uv-tools/`, on PATH |
| `betterleaks` | `1.1.2` (sha256-pinned) | `/usr/local/bin/betterleaks` |
| `pnpm` | `11.0.3` (sha256-pinned) | `/opt/pnpm/`, on PATH |
| `@commitlint/cli` | latest at image build (pnpm-installed) | `/usr/local/bin/commitlint` |
| `markdownlint-cli2` | latest at image build (pnpm-installed) | `/usr/local/bin/markdownlint-cli2` |

Refresh the floating versions by rebuilding the image: `REBUILD=1 ./setup.sh`.

## Templates dropped into each target repo

`bootstrap-repo.sh` copies the following from `templates/` into a target repo
(idempotent: existing files are skipped unless `--force` is passed):

| File | Purpose |
| --- | --- |
| `.pre-commit-config.yaml` | Hook list - what runs at which stage |
| `.betterleaks.toml` | Secret-scan rules + allowlist |
| `commitlint.config.js` | Conventional-commit rules |
| `.markdownlint-cli2.yaml` | Markdown lint config |
| `.editorconfig` | EOL/indent baseline |
| `.devcontainer/devcontainer.json` | VS Code Dev Containers config |

## Environment knobs

| Variable | Default | Purpose |
| --- | --- | --- |
| `REBUILD` | unset | Set to `1` to force `podman build` even if image exists |
| `TRACE` | unset | Set to `1` for `bash -x` xtrace through `setup.sh` |
| `NO_COLOR` | unset | Set to suppress ANSI colors in log output |
| `IMAGE_REF` | `localhost/dev-toolbox:fedora-43` | Override image reference |
| `CONTAINER_NAME` | `dev` | Override toolbox container name |
| `BUILD_NETWORK` | `slirp4netns` | Podman build network backend |

Inside the container, these are set automatically by the image (do not export
them yourself):

| Variable | Value | Purpose |
| --- | --- | --- |
| `UV_TOOL_DIR` | `/opt/uv-tools` | Where `uv tool install` writes |
| `UV_TOOL_BIN_DIR` | `/usr/local/bin` | Where uv tool shims land |
| `PRE_COMMIT_HOME` | `/opt/pre-commit-cache` | Where pre-commit caches envs |

## Verify

After `setup.sh` and `bootstrap-repo.sh`, confirm the disposal property:

```bash
toolbox enter dev
# Confirm tools are container-local
ls /usr/local/bin/uv /usr/local/bin/betterleaks /usr/local/bin/pnpm
ls /opt/uv-tools /opt/pnpm-global /opt/pre-commit-cache
# Confirm $HOME is host-shared (expected)
echo "$HOME"
ls -la "$HOME/.gitconfig" 2>/dev/null || echo "no host gitconfig"
# Confirm /srv/work is container-local
ls -ld /srv/work
exit

# Outside the toolbox, $HOME is unchanged; /srv/work does not exist on host.
ls /srv/work 2>&1   # expected: 'No such file or directory'
```

See [INSTALL.md](INSTALL.md) for the host prerequisites and signing-key
setup, and [PLAN.md](PLAN.md) for the deployment plan and iteration log.

## License

MIT - see [LICENSE](LICENSE).
