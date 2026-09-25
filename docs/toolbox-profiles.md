# Using Toolbox profiles

Use a Toolbox profile to work with development tools inside a Fedora container.
Your editor and terminal can stay on the host. Choose a profile, enter it, and
run your project's commands there.

This is the end-user guide for this repository. An **image** is the reusable
starting template; a **container** is your working environment created from it.
Rebuilding an image does not change an existing container.

## Choose a profile

| Your work | Profile | Enter command |
| --- | --- | --- |
| Git, shell scripts, Markdown and general repository checks | base | `toolbox enter dev-base` |
| Python applications and scripts | python | `toolbox enter dev-python` |
| Infrastructure scripts, YAML, network diagnostics and backup tooling | infra | `toolbox enter dev-infra` |

Python includes the base tools plus uv and Ruff. Infrastructure includes the
Python tools plus YAML utilities, network clients and Restic. See the
[full tool inventory](../README.md#profiles).

Node, Go and Rust development profiles are not provided yet. Tools such as
ShellSpec, Trivy and Ansible are not included in the initial infrastructure
profile. Follow your project's requirements before adopting a profile.

## First-time setup

Run setup on the **host**, as your normal user. You need an x86_64 Fedora host,
Bash 5.3 or newer, Podman and Toolbx. Initial builds and first-time dependency
installation require internet access. Setup does not install host packages.

The examples use this checkout location. Change it if you cloned elsewhere:

```bash
cd /var/home/aicloudopspecial/code/repos/dev-toolbox
./setup.sh python
```

Replace `python` with `base` or `infra` to create that environment. To create all
three, run setup once for each profile. The script builds missing parent images
automatically, but creates only the container you selected. Running `./setup.sh`
without an argument selects `base`.

If setup reports that the image and container already exist, they are ready to
use. List your environments from the host:

```bash
toolbox list
```

## Enter, leave and switch environments

From the host:

```bash
toolbox enter dev-python
```

You are now inside the Python container. Run `exit` to return to your previous
shell. Leaving the shell does not delete the container or its files.

To switch profiles, leave first, then enter the other container:

```bash
exit
toolbox enter dev-infra
```

To run one command without opening an interactive shell, use this from the host:

```bash
toolbox run --container dev-python python3 --version
```

## Choose where your project lives

| Location | Use it for | What happens when the container is removed? |
| --- | --- | --- |
| A directory under your home, such as `~/code/repos/myproject` | Work you want to keep across container replacements | Files remain on the host |

Your home directory is shared with Toolbox. Projects in `~/code/repos` are
available from every profile and remain on the host when a container is removed.

For an existing host project, enter the profile and navigate to it:

```bash
toolbox enter dev-python
cd ~/code/repos/myproject
git status
```

Replace `myproject` with your actual directory name. To clone a project, create
the directory if needed, then clone there:

```bash
mkdir -p ~/code/repos
cd ~/code/repos
git clone <repo-url> myproject
```

For host-shared projects, recreate virtual environments for a replacement
container when needed; do not assume one `.venv` works across different runtimes.

## Enable repository checks

For an existing project, follow its contributor instructions and keep its
existing hook policy. For a project adopting this repository's templates, run
the bootstrap **inside the chosen Toolbox**, from the project's directory:

```bash
/var/home/aicloudopspecial/code/repos/dev-toolbox/bootstrap-repo.sh --target "$PWD"
pre-commit run --all-files
```

The target must already be a Git repository. Bootstrap adds missing template
files and installs pre-commit and commit-msg hooks. It preserves existing files;
`--force` deliberately overwrites them, so reserve it for an intentional reset.
The first run downloads hook dependencies. Later offline runs depend on those
dependencies already being cached.

The supplied policy blocks commits on `main`, `master`, `develop` and `release/*`.
Use your project's feature-branch workflow. If a hook reformats a file, review
the change and run the checks again. `--all-files` checks tracked files; newly
created files need to be tracked or explicitly named with `--files`.

Markdown and commit-message checks install their own pinned tools. A missing
global `markdownlint-cli2` or `commitlint` command does not mean the hooks are
missing.

## Python daily workflow

Inside `dev-python` or `dev-infra`, navigate to the project. For a project that
already uses `pyproject.toml` and `uv.lock`:

```bash
uv sync --locked
uv run --locked python --version
```

`uv sync --locked` prepares the project's environment using its lockfile and
fails if that lockfile needs updating. It can download dependencies or a required
Python runtime. Use the project's documented test command; for example,
`uv run --locked pytest` works when pytest is declared in its dependencies.
See [uv project documentation](https://docs.astral.sh/uv/guides/projects/).

For a repository using the image's Ruff installation, these commands check
Python code without rewriting it:

```bash
ruff check .
ruff format --check .
```

If the project pins its own Ruff version, use its prescribed command instead.
Python libraries and test frameworks belong in the project environment, not the
system Python. Do not replace an existing project's package manager just to use
this Toolbox.

## Infrastructure daily workflow

Inside `dev-infra`, you can check which tools are available:

```bash
python3 --version
yamllint --version
restic version
```

Run the project's documented offline tests before using operational commands.
Having Restic or network clients installed does not configure credentials,
backups, router access or deployment permissions.

For MikroTik, retain the existing Devbox workflow until compatibility is tested.
The initial Toolbox build has Python 3.14, while that project's declaration uses
Python 3.13. The infrastructure profile is not yet a validated replacement.

## Use an editor

For a host-home project, open it in your usual editor and run its terminal
commands inside the appropriate Toolbox. Configure the editor's interpreter and
language tools to match the environment; host extensions do not automatically
use container tools.

For VS Code with Dev Containers, set `dev.containers.dockerPath` to `podman`.
Enter the Toolbox once to start it, then use **Dev Containers: Attach to Running
Container** and select `dev-python`, `dev-base` or `dev-infra`. Open your project
folder in that attached window.

The supplied **Reopen in Container** template uses the base image and may mount
the host workspace automatically. It does not select your Python or infra
Toolbox automatically. Prefer attaching when you want the existing profile.

## Check that a profile works

From the host checkout:

```bash
cd /var/home/aicloudopspecial/code/repos/dev-toolbox
bash scripts/verify.sh base
bash scripts/verify.sh python
bash scripts/verify.sh infra
```

Run only the checks for containers you created. Successful checks finish with
`PASS:` and the profile name. They test tools, writable managed directories,
synthetic secret detection, and applicable offline Python/YAML checks. They do
not validate your application's tests or infrastructure deployment readiness.

## Update without losing your work

Run these commands on the host to refresh the Python image and create a separate
replacement container:

```bash
cd /var/home/aicloudopspecial/code/repos/dev-toolbox
REFRESH=1 ./setup.sh python --build-only
CONTAINER_NAME=dev-python-next ./setup.sh python
bash scripts/verify.sh python dev-python-next
toolbox enter dev-python-next
```

Use an unused replacement name for each update. For base or infra, substitute
that profile and its container name throughout. A profile refresh also rebuilds
its parents. Fedora packages may advance; project lockfiles still govern project
dependencies. See the [version policy](../README.md#versions-and-updates).

Open or copy your project into the replacement, reinstall its dependencies and
run its tests. Keep the old container until this works. To return to the old
environment, exit the replacement and run `toolbox enter dev-python` on the host.

When the replacement works, you may stop and remove the old container from the
host:

```bash
podman stop dev-python
toolbox rm dev-python
```

Close its editor sessions first. Removal deletes container-installed changes;
projects under `~/code/repos` remain on the host. The replacement remains named
`dev-python-next`; continue entering it by that name.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| `toolbox` or `podman` is missing | Check the [host prerequisites](../INSTALL.md); setup will not install them for you. |
| Container not found | Run `./setup.sh` with the intended profile from the host checkout. |
| Existing container uses an older image | Follow the replacement workflow above; setup preserves the old container. |
| `uv` or `ruff` is missing | Exit and enter `dev-python` or `dev-infra`; they are not part of the base profile. |
| `pytest`, Ansible or another project tool is missing | Follow the project's dependency setup; these are not universally included. |
| Bootstrap cannot find a Git worktree | Run it from the actual project root after cloning or initializing the repository. |
| A hook cannot download dependencies | Restore network access and rerun it; first-time hook setup is not offline. |
| Files seem missing after switching profiles | Check that you opened the same `~/code/repos` project in each profile. |
| Build networking or editor attachment fails | See [installation troubleshooting](../INSTALL.md#troubleshooting). |

Toolbox shares your home directory and user-session resources. Treat code running
inside it as code running with access to your files; use a separately restricted
environment for untrusted code. Keep credentials out of image definitions.
