# dev-toolbox installation

Run on the host (Fedora 43 / 44 Workstation, Silverblue, or Kinoite). All
steps are idempotent.

## Host prerequisites

- Fedora 43 or 44 with `podman` and `toolbox` available
  (default on Silverblue/Kinoite; install on Workstation with
  `sudo dnf install -y podman toolbox`). The toolbox image is pinned to
  `fedora-toolbox:43` regardless of host — a Fedora 44 host running a 43
  toolbox is the supported configuration and is how `toolbox` is designed
  to work.
- `git` working tree of this repo (no network access required after clone).
- Bash 5.3+ (Fedora 43 default).
- `libatomic` is installed inside the toolbox image, so no host-side
  `libatomic` package is needed.

> [!IMPORTANT]
> The `setup.sh` script intentionally fails fast if `podman` or `toolbox` are
> missing. It never invokes `sudo` or `rpm-ostree install`.

## One-time host setup

```bash
git clone <this-repo> ~/dev-toolbox
~/dev-toolbox/setup.sh
```

The script:

1. Verifies `podman` and `toolbox` are on `PATH`.
2. Builds `localhost/dev-toolbox:fedora-43` from `Containerfile` if the
   image is missing (or if `REBUILD=1`).
3. Creates a toolbox container named `dev` from that image if missing.

Typical build time: 3 minutes on a warm dnf cache, 5 minutes cold.

## Per-repo bootstrap

```bash
toolbox enter dev
cd /srv/work
git clone <repo-url> myrepo
~/dev-toolbox/bootstrap-repo.sh --target /srv/work/myrepo
```

`bootstrap-repo.sh`:

1. Verifies the target is a git worktree (`.git` entry present).
2. Drops six template files at the repo root, skipping any that already
   exist (pass `--force` to overwrite).
3. Wires pre-commit into `.git/hooks/` for the `pre-commit` and
   `commit-msg` stages. (The `pre-push` stage is not wired because the
   template hook set declares no pre-push hooks; add it back when a
   pre-push hook lands.)

After the script returns, run a one-time audit:

```bash
cd /srv/work/myrepo
pre-commit run --all-files
```

The first run downloads each hook's isolated environment into
`/opt/pre-commit-cache` (container-local — disappears with `toolbox rm`).

## Signed-commit setup

The dev-toolbox templates do not install a signed-commit pre-push hook by
default. If you want to require commit signing, configure SSH-based signing
on the host once:

```bash
ssh-keygen -t ed25519 -C "git-signing" -f ~/.ssh/git-signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/git-signing.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

Then add `~/.ssh/git-signing.pub` to GitHub or your VCS host as a signing
key. The toolbox bind-mounts `$HOME/.ssh` and `$HOME/.gitconfig`, so the
signing setup is shared between the host and every toolbox.

> [!NOTE]
> Branch protection on `main` / `release/*`, required reviewers, and
> required status checks live on the remote (GitHub branch protection,
> Azure DevOps branch policies). Local hooks are fast feedback; remote
> policies are the real gate.

## Daily-use cheatsheet

| Goal | Command |
| --- | --- |
| Enter the toolbox | `toolbox enter dev` |
| Audit the whole tree | `pre-commit run --all-files` |
| Skip one hook for one commit | `SKIP=<hook-id> git commit ...` |
| Skip all hooks (last resort) | `git commit --no-verify` |
| Bump pinned hook revisions | `pre-commit autoupdate` |
| Reset everything | `toolbox rm dev && ~/dev-toolbox/setup.sh` |
| Force image rebuild | `REBUILD=1 ~/dev-toolbox/setup.sh` |

## Troubleshooting

### `libatomic.so.1: cannot open shared object file`

The image installs `libatomic` so this should not occur. If you forked the
Containerfile and removed `libatomic` from the `dnf install` block, restore
it - pre-commit's `nodeenv`-built Node binary dynamically links it.

### `passt-selinux` AVC during podman build

Fedora 43's `selinux-policy` package has a known AVC for `pasta_t` mounting
on `tmpfs_t`. `setup.sh` works around this by defaulting
`--network=slirp4netns`. Override to `pasta` with
`BUILD_NETWORK=pasta ./setup.sh` once the upstream policy lands.

### VS Code Dev Containers can't find the `dev` container

Confirm the dockerPath override is set:

```bash
grep dev.containers.dockerPath ~/.config/Code/User/settings.json
```

Should print `"dev.containers.dockerPath": "podman"`. Restart VS Code after
adding that setting.

### `bootstrap-repo.sh: required command not found on PATH`

The script must run inside the toolbox (`toolbox enter dev` first). It
expects pre-commit and git on PATH; both are baked into the image.
