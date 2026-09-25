# dev-toolbox installation

Use a Fedora host with Bash 5.3+, Podman and Toolbx available. Setup fails if
a prerequisite is missing; it does not install host packages.
The image uses Fedora 44 independently of the host release. An initial build
needs network access for the Fedora base, signed packages and Betterleaks.

## Setup and daily use

For a guided walkthrough, use the [Toolbox profiles user guide](docs/toolbox-profiles.md).

Follow the canonical [setup instructions](README.md#setup) to build and create
the base, Python and infrastructure environments. The default container is now
`dev-base`; an existing legacy `dev` container is preserved.

See [versions and updates](README.md#versions-and-updates) for rebuilding,
replacement containers and rollback. Repositories in `~/code/repos` remain on
the host when a container is removed. See [verification](README.md#verification)
for checks.

Inside your chosen container, run
`bootstrap-repo.sh --target ~/code/repos/<repo>`.
The first hook installation downloads isolated dependencies into
`/opt/pre-commit-cache`. Commitlint and markdownlint are provided through these
hooks rather than global Node packages.

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

## Troubleshooting

### Existing container uses an older image

Setup deliberately stops instead of recreating a container containing work.
Use a new name, for example `CONTAINER_NAME=dev-python-next ./setup.sh python`,
verify it, and preserve the old workspace before any manual removal.

### Node hook reports missing libatomic

The base image includes `libatomic` for hook-managed Node binaries. Check the
container's image and rebuild the base if using an older or customized image.

### Build networking fails

Setup retains `BUILD_NETWORK=slirp4netns` from the previous configuration.
If that backend is unavailable on your host, select an installed backend with
`BUILD_NETWORK=pasta ./setup.sh base`. Investigate actual network or SELinux
errors before changing host security settings.

### VS Code cannot find the container

Set `dev.containers.dockerPath` to `podman`, start the selected Toolbox,
and attach to its new profile name, such as `dev-python`.

### Bootstrap cannot find pre-commit

Run it inside a profile container. Each profile includes Git and pre-commit.
