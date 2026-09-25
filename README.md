# dev-toolbox

Three Fedora Toolbx images provide a shared development baseline and focused
Python and infrastructure profiles. Build definitions live in this repository;
images live in your user's rootless Podman storage.

Start with the [Toolbox profiles user guide](docs/toolbox-profiles.md) for
profile selection, first-time setup, daily commands, project storage, updates
and troubleshooting.

## Profiles

| Profile | Image | Container | Added tools |
| --- | --- | --- | --- |
| base | `localhost/dev-base:fedora-44` | `dev-base` | Git, gh, curl, SSH, jq, ripgrep, archives, make, pre-commit, ShellCheck, shfmt, Betterleaks |
| python | `localhost/dev-python:fedora-44` | `dev-python` | Base plus Python, uv and Ruff |
| infra | `localhost/dev-infra:fedora-44` | `dev-infra` | Python plus PyYAML, yamllint, OpenSSL, iproute, ping, DNS tools, Ncat and Restic |

The base is `Containerfile`; derived definitions are in `profiles/`.
Infrastructure inherits Python so it shares the same Python tools.
Python is already present in the base as a pre-commit dependency, but uv and
Ruff belong to the Python profile. `libatomic` supports Node binaries downloaded
by the existing pre-commit hooks.

Node, pnpm, commitlint and markdownlint are no longer installed as global image
tools. Existing pinned hooks provision their own runtimes and dependencies.
Project frameworks, tests and libraries belong in project manifests and lockfiles.
ShellSpec, Trivy, Ansible and deployment tooling require a project-specific
extension and validation; this initial profile does not replace MikroTik's Devbox
environment or its deployment gates.

## Setup

On a Fedora host with Bash 5.3+, Podman and Toolbx:

```bash
./setup.sh base
./setup.sh python
./setup.sh infra
toolbox enter dev-python
```

No argument selects `base`. Setup builds missing parents automatically.
Build images without creating containers using `./setup.sh infra --build-only`.
Existing containers are reused only when their image ID matches. A mismatch
stops with a recovery message; rebuilding an image does not update a container.

Inside your chosen Toolbox:

```bash
mkdir -p ~/code/repos
cd ~/code/repos
git clone <repo-url> myrepo
~/dev-toolbox/bootstrap-repo.sh --target ~/code/repos/myrepo
cd myrepo
pre-commit run --all-files
```

The bootstrap copies six templates and installs pre-commit and commit-msg hooks.
Existing files are preserved unless explicitly invoked with `--force`.
First-time hook setup needs network access.

For an optional host pnpm installation, see
[host pnpm installation and removal](docs/host-pnpm.md).
Host prerequisites and signing setup are in [INSTALL.md](INSTALL.md).

## Storage and security

Toolbx shares the host home directory and user session. Use it for trusted
development; it is not a security sandbox. Keep credentials outside images.
Untrusted scripts and agents need a separately configured restricted container.

| Location | Purpose | Persists after container removal? |
| --- | --- | --- |
| `~/code/repos` | Host-shared project workspace | Yes |
| `/opt/pre-commit-cache` | Hook environments | No |
| `/opt/uv-tools`, `/opt/uv-bin` | User-installable Python tools | No |
| `/opt/uv-cache`, `/opt/uv-python` | uv cache and managed Python versions | No |
| Host home directory | Identity, editor state, host repositories | Yes |

Managed directories are writable with a sticky bit for Toolbx's host UID.
Other programs can still write to shared home; these settings do not guarantee
that all development activity stays inside container storage.
Repositories under `~/code/repos` remain available after removing a container.

For VS Code, set `dev.containers.dockerPath` to `podman`, start the Toolbox,
then use **Attach to Running Container** and open `~/code/repos/myrepo`.
The supplied Dev Container template defaults to the base image. **Reopen in
Container** can automatically mount the host workspace even without an explicit
`workspaceMount`; that workspace is not disposable container storage.

## Versions and updates

`versions.env` selects Fedora 44. Fedora packages, including uv and Ruff, follow
signed Fedora repository updates; a rebuild can resolve newer versions.
Betterleaks retains its exact version and SHA-256 in `Containerfile`.
This is not a byte-for-byte reproducible build or a frozen RPM snapshot.

Each image records resolved RPM versions in
`/usr/share/dev-toolbox/rpm-manifest.txt`. Inspect the image ID with
`podman image inspect --format '{{.Id}}' localhost/dev-python:fedora-44`.
Derived builds use the local parent's exact image ID and rebuild when it changes.

Review updates monthly and promptly for applicable security fixes. Rebuild and
verify all profiles together, retain the old containers during validation, and
record image IDs before replacing any environment:

```bash
REFRESH=1 ./setup.sh infra --build-only
CONTAINER_NAME=dev-infra-next ./setup.sh infra
bash scripts/verify.sh infra dev-infra-next
```

Keep the old container until its work is preserved and the replacement passes.
Rollback consists of re-entering the old container. Setup never removes it.
After editing a definition, use `REBUILD=1`; ordinary reruns reuse existing images.
`REBUILD=1` permits cached layers. Use `REFRESH=1` to pull the Fedora base and
rerun package installation without cached layers when applying upstream updates.

| Variable | Default | Purpose |
| --- | --- | --- |
| `REBUILD` | unset | Set to `1` to rebuild the selected profile and parents |
| `REFRESH` | unset | Set to `1` to pull the Fedora base and rebuild without cache |
| `IMAGE_REF` | Profile image above | Override final image tag |
| `CONTAINER_NAME` | Profile container above | Override final container name |
| `BUILD_NETWORK` | `slirp4netns` | Podman build network backend |
| `TRACE` | unset | Set to `1` for setup shell tracing |
| `NO_COLOR` | unset | Disable colored setup messages |

## Verification

```bash
bash scripts/test-setup.sh
bash scripts/verify.sh base
bash scripts/verify.sh python
bash scripts/verify.sh infra
./scripts/check-precommit-parity.sh
pre-commit run --all-files
```

The setup tests use mock runtimes to check profile ordering, reuse and failures.
The verifier runs inside each real Toolbox, checks tool availability and writable
managed paths, and exercises Python/YAML locally without downloading dependencies.
See the [execution record](docs/plans/2026-09-18-toolbox-profiles.md) for actual
results and remaining gates. [PLAN.md](PLAN.md) retains historical work.

## Sources

Package availability checked against Fedora's
[uv package](https://packages.fedoraproject.org/pkgs/uv/uv/) and the actual image
build transactions. See [Toolbx documentation](https://containertoolbx.org/doc/)
for its host integration.

## License

MIT — see [LICENSE](LICENSE).
