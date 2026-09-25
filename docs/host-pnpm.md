# pnpm on Fedora 44 Kinoite

Use [`scripts/pnpm-host.sh`](../scripts/pnpm-host.sh) to install or uninstall
pnpm for your normal user. This optional host utility is separate from the
dev-toolbox container image. It supports Fedora 44 Kinoite on x86_64 with
Bash 5.3+, using the standard directories beneath your home directory.

This is the authoritative guide for the script. Historical test results and
remaining repository gates are in the [execution record](plans/2026-09-15-host-pnpm.md).

## Requirements and command reference

Run the script with Bash on the host as the account that will own pnpm.
It checks `ID=fedora`, `VERSION_ID=44`, and `VARIANT_ID=kinoite` from
`/etc/os-release`, plus `uname -m` equal to `x86_64`. Other Fedora variants,
versions and architectures are intentionally rejected.

`HOME` must resolve to an existing directory owned by your user, other than `/`.
The resolved path may contain only letters, numbers, `/`, `.`, `_`, and `-`.
Spaces and shell metacharacters are unsupported because generated files embed
literal paths. The script resolves HOME first, then rejects symlinks in managed
paths below that resolved directory. The normal Fedora `/home` alias can thus
resolve to `/var/home` without changing the installation layout.

Explicitly checked utilities are `realpath`, `stat`, `awk`, `cmp`, `cp`, `mv`,
`mkdir`, `mktemp`, `flock`, `sha256sum`, `tar`, `install`, and `readlink`.
Normal host utilities such as `uname`, `cat`, `rm`, `rmdir`, `grep`, and `sed`
must also be available. Online install requires `curl`; offline install and
uninstall do not. `systemctl` is optional. No `sudo`, `dnf`, or `rpm-ostree`
operation is performed.

| Command or option | Meaning |
| --- | --- |
| `./scripts/pnpm-host.sh` | Print help; same as `--help` or `-h` |
| `./scripts/pnpm-host.sh install` | Install or reinstall the pinned release |
| `./scripts/pnpm-host.sh install --adopt` | Permit takeover of a pre-existing home and exact recognized legacy integration |
| `./scripts/pnpm-host.sh install --archive FILE` | Use a local copy of the pinned archive |
| `./scripts/pnpm-host.sh status` | Report managed, unmanaged, or absent at the fixed installation path |
| `./scripts/pnpm-host.sh uninstall` | Archive a managed installation and remove its integration |

Place options after `install`. Both install options can be combined. There is
no `update`, `latest`, `purge`, `dry-run`, or configurable-version option.
Help still requires Bash 5.3+, but skips host checks. The host, path and
login-file checks apply to `status` as well as modifying commands.

`status` checks for the `installed` marker and an executable launcher, then
runs that launcher with `--version`. It does not validate the ownership
manifest or check which pnpm your current PATH selects. Managed, unmanaged
and absent reports all normally exit successfully; do not use its exit code
alone as an installed/not-installed test.

## Install

Run from the repository on the host, without sudo:

```bash
./scripts/pnpm-host.sh install
./scripts/pnpm-host.sh status
```

The script downloads the official pnpm **12.4.2** Linux archive, checks its
hardcoded SHA-256 before extraction or execution, and installs the native
executable and its accompanying `dist/` files. It does not install Node.js,
npm, system packages, or DeepSeek Harness. Node-based applications still
need an appropriate runtime.

An existing pnpm home requires explicit adoption:

```bash
./scripts/pnpm-host.sh install --adopt
```

Adoption preserves pnpm-managed Node runtimes and global packages. It backs up
the existing launcher and replaces only recognized legacy pnpm shell blocks,
the known desktop configuration, matching completions, and exact wrappers
from the earlier host setup. Unknown or edited configurations cause a refusal
before installation changes. Backups may contain your shell configuration;
they are stored in a private state directory.

For offline installation, download the exact archive ahead of time:

```bash
./scripts/pnpm-host.sh install --archive /path/to/pnpm-linux-x64.tar.gz
```

The checksum is still mandatory. Repeated installs use the same pinned release
and do not duplicate shell entries. Each modifying run retains a recovery
snapshot. To update the pin, maintainers must update both the version and digest
from the [official release](https://github.com/pnpm/pnpm/releases/tag/v12.4.2).

### Download method and verification

The script uses this fixed release asset:

```text
https://github.com/pnpm/pnpm/releases/download/v12.4.2/pnpm-linux-x64.tar.gz
SHA-256: ce1ed690fe9c2f091d7267e1afbe9380abb08bb577e95348fda194a41147d2ec
```

This repository implements its own installation and shell integration around
the official release archive. It does not execute the upstream
`get.pnpm.io/install.sh` installer or use npm/Corepack. Upstream also documents
a standalone installation method that works without Node.js; see
[pnpm installation](https://pnpm.io/installation).

Downloads permit HTTPS redirects only, require TLS 1.2 or newer, use a
15-second connection timeout and a 300-second per-attempt maximum, and allow
two retries. A local `--archive` file is copied into temporary work storage.
In either case, the checksum is verified before extraction or execution.
The script then requires an executable `pnpm`, a `dist/` directory, and an
exact version match, and generates Bash completion using that executable.
The pinned digest checks archive identity; the script does not independently
verify a publisher signature.

### Adopting an existing installation

Adoption is deliberately narrow. It recognizes the exact earlier `# pnpm`
block and the earlier repaired Toolbx-aware block, plus the current generated
block. Whitespace or content changes within those blocks can cause refusal.
The legacy desktop file must match the expected two lines, and pre-existing
completion must match output generated by the pinned release.

For `.local/bin/pnpm`, `pnpx`, `node`, `npm`, and `npx`, only the exact earlier
two-line shell wrappers pointing into this account's pnpm `bin/` directory
are accepted. Accepted wrappers are backed up and removed. Unrelated commands
and symlinks are rejected, even with `--adopt`.

Adoption installs the pinned distribution; it is not merely an ownership
registration. It needs a download or the exact offline archive:

```bash
./scripts/pnpm-host.sh install --adopt --archive /path/to/pnpm-linux-x64.tar.gz
```

If `status` reports unmanaged, adoption is required before this script can
uninstall it. Preserve and reconcile unknown configurations manually first;
`--adopt` is not a force-overwrite switch.

## Shell and desktop integration

The script manages these locations:

| Location beneath HOME | Purpose |
| --- | --- |
| `.local/share/pnpm/.kinoite/` | Native executable and accompanying files |
| `.local/share/pnpm/bin/` | pnpm and pnpx launchers; existing runtimes are preserved |
| `.config/pnpm-kinoite/env.bash` | Host PATH setup and Toolbx PATH cleanup |
| `.bashrc`, `.bash_profile` | Marked source blocks; other user content is preserved |
| `.config/environment.d/10-pnpm.conf` | Environment for desktop sessions |
| `.local/share/bash-completion/completions/pnpm` | Bash completion |
| `.local/state/pnpm-kinoite/` | Ownership records, lock and recovery snapshots |

The fixed standard layout is intentional; `PNPM_HOME` and XDG environment
overrides do not redirect installation. Symlinks in managed paths, root
execution, unsupported systems, and execution inside containers are rejected.
If `.bash_profile` is absent but `.bash_login` or `.profile` exists, the script
refuses to create a file that would hide your existing login setup.

Host Bash shells add pnpm's bin directory to PATH. Toolbx-marked shells remove
inherited host pnpm paths and unset only the host PNPM_HOME, retaining a
container-specific value. Install container tools independently. This shell
setup is not a sandbox and does not prevent explicit access to host files.

When available, the script updates only PATH and PNPM_HOME in the systemd user
manager. Offline sessions are supported. Open a new terminal after running it;
log out and back in for a desktop-wide refresh. Already-running applications
retain their old environment. No launchers are installed in `.local/bin`.

### Generated files and ownership

`bin/pnpm` executes the absolute `.kinoite/pnpm` path and forwards arguments.
`bin/pnpx` executes the same binary with `dlx` followed by the arguments.
Both launchers use mode 755. The helper, desktop file and completion use
mode 644. Existing startup-file modes are preserved; new startup files use
644. State and transaction directories are created under a restrictive
`umask 077`; backups can contain private shell configuration.

Both Bash startup files receive this block, with the actual canonical home
substituted for `/canonical/home`:

```bash
# >>> pnpm-kinoite >>>
if [ -r "/canonical/home/.config/pnpm-kinoite/env.bash" ]; then
    . "/canonical/home/.config/pnpm-kinoite/env.bash"
fi
# <<< pnpm-kinoite <<<
```

Keep custom shell settings outside the block. Duplicate, malformed, unknown,
or edited pnpm blocks are refused. Any `PNPM_HOME` text outside a recognized
block, including in comments, is also treated as a conflict. Rendered startup
files pass `bash -n` before mutation. Other lines are preserved, although
rewriting normalizes a missing final newline.

The desktop file contains a managed comment followed by:

```text
PNPM_HOME=/canonical/home/.local/share/pnpm
PATH=${PNPM_HOME}/bin:${PATH}
```

The state directory contains:

| Entry | Role |
| --- | --- |
| `installed` | Version recorded at the last successful installation |
| `files.sha256` | Digests of helper, desktop file, completion and two launchers |
| `created-shells` | Startup files initially absent, eligible for removal if empty on uninstall |
| `lock` | File used by `flock` to serialize modifying operations |
| `work.XXXXXXXX/` | Temporary staging, normally removed on exit |
| `install.XXXXXXXX/`, `uninstall.XXXXXXXX/` | Retained recovery snapshots |

Reinstall and uninstall verify the five manifest-covered files before changes.
The manifest does not cover the complete native distribution, global packages,
runtimes, or whole startup files. It is an ownership/conflict check, not a
complete integrity audit. Do not remove the state directory while keeping the
installation: doing so loses the script's management and recovery records.

### Toolbx and session boundaries

The installer rejects `/run/.toolboxenv`, `/run/.containerenv`, and
`/.dockerenv`. The generated Bash helper specifically checks
`/run/.toolboxenv`: in that environment it removes every exact host pnpm root
and root/bin PATH component, preserving other components and their order.
It leaves a container-specific `PNPM_HOME` intact. On the host it prepends
the bin directory only when absent; an existing entry is not moved forward.

The helper supports Bash startup files only. Other shells need separate
integration. Noninteractive, non-login Bash does not automatically load these
files; its inherited environment matters. Tools addressed by absolute host
paths remain accessible from a shared-home container.

The optional session update reads the systemd user manager's existing PATH,
removes exact host pnpm entries, then prepends the bin directory on install.
On uninstall it unsets the manager's PNPM_HOME only when it matches this home.
It preserves other variables and PATH entries. An unavailable manager or empty
manager PATH skips the update. Reported update failures are warnings after the
file changes have committed; they do not undo installation or removal.

### Checking the active installation

After opening a new terminal, run from outside a project with a pnpm version pin:

```bash
/path/to/dev-toolbox/scripts/pnpm-host.sh status
type -a pnpm pnpx
pnpm --version
printf 'PNPM_HOME=%s\n' "${PNPM_HOME-}"
```

Replace the repository placeholder with your checkout path. The managed launcher
should be in `$HOME/.local/share/pnpm/bin`. Another alias or earlier PATH entry
can still take precedence. Native pnpm running successfully does not establish
that a Node-based application has its required runtime and dependencies.

## Updating the pinned version

There is no automatic update mechanism in this script. Re-running `install`
installs **12.4.2**, with a fresh verification and snapshot; it does not resolve
the latest release and is not a no-op even when the version is unchanged.

Upstream [`pnpm self-update`](https://pnpm.io/cli/self-update) can update the
global installation outside a pinned project. Within a project with a pnpm
package-manager pin, it updates the project's pin instead. This script uses
custom launchers and an ownership manifest: an external updater may replace
those launchers and make subsequent script operations refuse the installation.
Compatibility with global self-update has not been validated. It is therefore
not a supported update procedure for this managed layout.

To maintain this installer for a newer release:

1. Obtain the matching Linux x64 archive and its published digest from the
   official pnpm release. Review any distribution-layout changes.
2. Update `PNPM_RELEASE`, `SHA256`, the help text, version-specific tests and
   this guide together. Review the URL if asset naming changes.
3. Run syntax, ShellCheck, repository checks and the isolated lifecycle suite
   against that exact archive. Include reinstall over the previously supported
   managed version and recovery testing; do not assume fresh-install coverage
   proves upgrade compatibility.
4. Record the tested artifact and results, then run the reviewed script's
   `install` command for the target account. Keep the recovery snapshot.

Do not bypass checksum/ownership failures by deleting the manifest. Reconcile
external changes or restore a matching snapshot before proceeding.

## Uninstall and recovery

```bash
./scripts/pnpm-host.sh uninstall
```

Uninstall requires an installation managed or adopted by this script. It
removes its shell blocks, desktop configuration, completion, and ownership
records. It moves the entire pnpm home to the printed
`.local/state/pnpm-kinoite/uninstall.XXXXXXXX/pnpm-home` recovery directory.

Consequently, any Node runtimes and global commands stored inside that pnpm
home also leave active use. Their data remains in the archive. Project
`node_modules`, project lockfiles, external package stores, and external
runtime managers are preserved. Empty startup files created by the script
are removed; files with user-added content remain. Repeated uninstall is a
successful no-op. There is no automatic backup purge.

If a managed file has been edited, uninstall stops so you can preserve or
reconcile the edit. The ownership digest list is `files.sha256` in the state
directory. Shell files allow edits outside their exact managed blocks.

Installation and removal save each changed file before mutation and restore
those snapshots on ordinary command failure or interruption. Abrupt termination
such as SIGKILL or power loss cannot run that recovery handler. Keep the printed
snapshot until you have verified your environment.

For manual recovery, inspect the snapshot and compare it with your current
files first. `bashrc` and `bash_profile` are the previous startup files;
`env.bash`, `desktop`, and `completion` are previous integration files.
An uninstall snapshot's `pnpm-home` can be moved back only when the active
pnpm home is absent. Restore the saved `installed`, `files.sha256`, and
`created-shells` state files together with their matching installation and
configuration. Reopen your session afterward. Preserve newer edits instead
of blindly copying whole startup files over them.

### Transaction behavior and backup contents

After environment checks, a modifying command takes a nonblocking lock and
stages its files. Configuration checks, download, checksum and version checks
complete before a recovery snapshot is created. Preflight failure can leave
the state directory and lock file, but does not replace installation files.

During mutation, each target is registered for rollback only after its existing
contents were successfully saved. Ordinary failures restore registered targets
in reverse order. Uninstall first moves the pnpm home into its snapshot;
rollback moves it back. Snapshots remain, and some empty parent directories can
remain after recovery. This is a shell transaction, not a filesystem-wide
atomic operation; concurrent manual edits are not protected by its lock.

Only previously existing targets appear as backup entries:

| Snapshot entry | Original destination beneath HOME |
| --- | --- |
| `bashrc`, `bash_profile` | `.bashrc`, `.bash_profile` |
| `env.bash` | `.config/pnpm-kinoite/env.bash` |
| `desktop` | `.config/environment.d/10-pnpm.conf` |
| `completion` | `.local/share/bash-completion/completions/pnpm` |
| `installed`, `files.sha256`, `created-shells` | Same names in `.local/state/pnpm-kinoite/` |
| `wrapper-NAME` | `.local/bin/NAME`, for an adopted legacy wrapper |
| `release` | `.local/share/pnpm/.kinoite/`, on reinstall |
| `pnpm`, `pnpx` | Corresponding files in `.local/share/pnpm/bin/`, on install |
| `pnpm-home` | Entire `.local/share/pnpm/`, on uninstall |

Install snapshots are not a complete copy of the pnpm home. Existing globals
and runtimes stay in place during install. An uninstall snapshot holds the
entire home, including anything else stored there. Snapshots have no automatic
retention limit. Uninstall leaves the lock and backups, and may leave empty
configuration directories; it is not a disk-space purge.

### Manual recovery procedure

1. Stop installation attempts and preserve the printed snapshot. If the process
   is still running, allow its normal rollback to finish before intervening.
2. Inspect that specific snapshot and compare the mapped files above with their
   active counterparts. A first-install snapshot may have no old state files;
   absence is meaningful. A failed uninstall that rolled back may no longer
   contain `pnpm-home`, because it was moved back successfully.
3. Save newer user edits separately. For uninstall recovery, move `pnpm-home`
   back only if the active destination is absent. For reinstall recovery,
   restore the saved distribution and launchers together. Do not merge two
   native distributions or overwrite an unrelated installation.
4. Restore matching integration and ownership records from the same transaction.
   Preserve unrelated startup-file edits by reconciling the managed source
   blocks instead of blindly replacing whole files. Restore legacy wrappers
   only when intentionally returning to the earlier legacy layout.
5. Check restored shell syntax and, for a restored managed installation, its
   recorded digests and status:

   ```bash
   bash -n "$HOME/.bashrc" "$HOME/.bash_profile"
   sha256sum --check "$HOME/.local/state/pnpm-kinoite/files.sha256"
   /path/to/dev-toolbox/scripts/pnpm-host.sh status
   ```

   Check only shell files that exist. An intentionally restored unmanaged
   installation has no managed manifest; skip that check in that case.
6. Open a new terminal and log out/in to refresh desktop processes. Verify
   command selection and the applications that depend on pnpm-managed runtimes.

There is no universal restore command: the correct action depends on which
files existed before the transaction and whether automatic rollback completed.
Delete recovery data manually only after deciding its globals, runtimes and
configuration backups are no longer needed.

## Errors and troubleshooting

Errors normally print to standard error; successful operations print the
snapshot path. Exit codes below describe explicit script checks. External
utilities may return their own codes, so this is not an exhaustive mapping.

| Exit code | Meaning and next action |
| --- | --- |
| `0` | Command completed; session refresh may still be needed. Status can report absent with this code. |
| `64` | Invalid command/options or unsupported characters in HOME; check help and the path. |
| `65` | Ambiguous shell configuration, archive checksum/content/version failure; inspect the error and preserve existing files. |
| `69` | Unsupported Bash/OS/architecture or missing required utility; use the supported host environment. |
| `73` | Ownership/configuration conflict, missing state or missing managed home; compare with recovery data before retrying. |
| `74` | A rollback restore/remove operation failed; inspect the retained snapshot and active files. |
| `75` | Another modifying operation holds the lock; wait for it to finish. Removing the lock file is not a remedy. |
| `77` | Root/container execution, invalid home ownership, or a rejected symlink/path; correct the environment or layout. |
| `130`, `143` | Interrupted by SIGINT or SIGTERM; the exit handler attempts rollback before file commit. |

Common cases:

- **Unmanaged pnpm home:** inspect the setup, then use `install --adopt` only
  when its recognized migration matches what you want to preserve.
- **Modified managed files:** compare the five manifest entries with the
  corresponding backup. Save intentional edits and restore consistent files;
  `--adopt` does not bypass managed integrity checks.
- **Existing `.profile` or `.bash_login`:** when `.bash_profile` is absent,
  integrate the existing login logic deliberately before retrying. Creating a
  blank `.bash_profile` merely to bypass the guard can hide that logic.
- **Checksum mismatch:** obtain the exact pinned archive again. Do not change
  the expected digest just to accept an unexplained mismatch.
- **Download failure:** check network/proxy access to the official asset or
  supply an independently obtained matching archive. No install files should
  have been replaced at this stage.
- **Old version after install or command still present after uninstall:** open
  a fresh session and inspect `type -a pnpm`; another installation, alias,
  project pin or inherited environment may explain the result.
- **Session update warning:** file changes already succeeded. Log out and back
  in; repeated installation is not required just to refresh running processes.
- **Failed rollback, power loss or SIGKILL:** retain state and backups and use
  the manual recovery procedure before another modifying run.

## Validation

Run the lifecycle suite on a non-root Fedora 44 Kinoite x86_64 account with
`bwrap` available:

```bash
bash -n scripts/pnpm-host.sh scripts/test-pnpm-host.sh
./scripts/test-pnpm-host.sh /path/to/pnpm-linux-x64.tar.gz
```

Tests mount a temporary home over the account home in a private namespace,
execute the actual checksum-verified release, and mock download failures and
user-manager commands. They exercise install/uninstall, adoption, conflicting
configuration, rollback, and Toolbx marker behavior. Fixtures are retained under
the printed `/tmp/test-pnpm-host.XXXXXXXX` directory for inspection.

The companion [test script](../scripts/test-pnpm-host.sh) is for maintainers;
it is not needed for ordinary installation. Its archive argument must identify
the pinned release. It needs working unprivileged `bwrap` namespaces and uses
temporary fixtures rather than installing into the live account. Fixtures and
logs may retain copied configuration, so inspect them before sharing.

Before shipping implementation changes, also run the repository's configured
ShellCheck and pre-commit checks. Follow [CONTRIBUTING.md](../CONTRIBUTING.md)
for the repository workflow. Record failures separately from passing scoped
checks, and do not claim a real host or container test from fixture results.

A Toolbx marker with fixture command paths does not certify a real Toolbox
image. When a `dev` container exists, additionally check command paths and
versions with `toolbox run --container dev bash -lc 'command -v pnpm node'`
and in an interactive `toolbox enter dev` session.

Upstream references: [installation](https://pnpm.io/installation) and
[uninstallation](https://pnpm.io/uninstall). This utility retains recovery data
instead of recursively deleting the pnpm home.
