# dev-toolbox deployment plan

Status: in progress (see task table below).
Owner: Sergio Tapia (`sergio.tapia_contractor@jmfamily.com`).
Started: 2026-05-13.

## Goal

Deliver a forked, generic dev-toolbox that satisfies all four user
requirements (recap from the design conversation):

1. **Bootstrap any repo inside a toolbox environment.**
2. **Reproducibility and consistency** across host rebuilds — same image,
   same pinned versions everywhere.
3. **Do not touch the immutable Fedora host** — no `rpm-ostree install`, no
   host `dnf`, no writes outside `$HOME` or the container.
4. **`toolbox rm dev` deletes everything** — every tool and every repo
   cloned inside the toolbox disappears with the container; only the user's
   `$HOME` config (dotfiles, VS Code Server cache, SSH keys) survives.

The `repo-bootstrap` skill is the wrong tool for requirement (4) — it
installs into `$HOME` deliberately, so toolbox rebuild does not reset
anything. The `scripts/.toolbox/` image is the right shape but is
scripts-repo-specific; dev-toolbox is a generic fork.

## Acceptance criteria (A+ bar)

The deliverable is **A+** when, and only when, all of the following hold:

1. `podman build` of `Containerfile` succeeds on a fresh host with no
   warnings about uninstalled packages or sha256 mismatches.
2. After `toolbox create --image localhost/dev-toolbox:fedora-43`, every
   tool listed in the README's "What ships in the image" table is on PATH
   and reports a non-empty `--version`.
3. After running `bootstrap-repo.sh` against a fresh git repo at
   `/srv/work/test-bootstrap`, all six template files are present and
   `pre-commit run --all-files` exits 0 on the empty tree (no hooks fail
   on absence of content).
4. `toolbox rm dev` followed by `ls /srv/work` on the host returns **No
   such file or directory** — proving the workspace is container-local.
5. `toolbox rm dev` followed by `ls ~/.local/share/uv/tools` on the host
   shows no dev-toolbox-installed tools — proving the post-build `uv tool
   install` did not leak into `$HOME`.
6. `pnpm dlx markdownlint-cli2@0.22.1` and `pnpm dlx shellcheck@4.1.0`
   report **0 errors** across every script and markdown file in the repo,
   using the gates documented in
   `/home/conpwxp/repos/review/CLAUDE.md`.
7. The `code-reviewer` subagent reports **no Critical and no Warning**
   findings on its final pass; remaining Suggestions are explicitly
   accepted as deliberate trade-offs in this plan.

Items 1, 2, 3, 4, and 5 require a real Fedora host with `podman` and
`toolbox` installed and are out of reach in WSL2. They are documented as
**user-verified** steps with copy-paste commands and expected outputs.

Items 6 and 7 can run locally in WSL2 Fedora 43 and gate this plan before
hand-off.

## Task table

| ID | Task | Status | Notes |
| --- | --- | --- | --- |
| 1 | Install local validation tools (pnpm-based) | done | markdownlint-cli2 v0.22.1, shellcheck 0.11.0 reachable via `pnpm dlx`. |
| 2 | Containerfile, setup.sh, bootstrap-repo.sh | done | All scripts under `/home/conpwxp/repos/dev-toolbox/`. |
| 3 | Six templates + own-repo configs | done | Under `templates/`. Azure AD client-secret regex tightened with assignment context. |
| 4 | Project docs (README, INSTALL, PLAN, CHANGELOG, CONTRIBUTING) | done | This file is the plan. |
| 5 | Static validation: `bash -n`, shellcheck, markdownlint | pending | Per acceptance criterion 6. |
| 6 | Code-reviewer agent iteration | pending | Per acceptance criterion 7. Cap at 3 passes. |
| 7 | Create test repo `test-bootstrap` | pending | Sample repo to exercise bootstrap-repo.sh. |
| 8 | E2E runbook (user-verified on Fedora host) | pending | Acceptance 1-5, documented in `review/dev-toolbox-deployment.md`. |
| 9 | Final report at `review/dev-toolbox-deployment.md` | pending | Workspace deliverable. |

## Iteration log

Records every code-reviewer pass, the verdict it returned, and what was
applied or deferred between passes.

### Pass 0 - first draft (2026-05-13)

Initial artifacts written. Static validators clean
(`bash -n`, `shellcheck@4.1.0`, `markdownlint-cli2@0.22.1`, plus
JSON/YAML/TOML syntax checks).

### Pass 1 - code-reviewer subagent (2026-05-13)

Result: **0 Critical, 0 Warnings, 3 Suggestions** - already at A+ bar.

Applied:

- Suggestion 2: Fixed citation drift at `Containerfile:14` (the inline
  comment referenced line 134 but the actual `RUN mkdir -p /srv/work` is
  at line 124). Replaced the brittle line pointer with prose ("the final
  `RUN mkdir -p /srv/work` block near the end of this file").
- Suggestion 1: Dropped `pre-push` from
  `templates/.pre-commit-config.yaml`'s `default_install_hook_types`
  because no hook in the template targets pre-push, so wiring it would
  materialise a no-op `.git/hooks/pre-push`. Updated the matching log
  line in `bootstrap-repo.sh` and the matching prose in `INSTALL.md`.

Accepted as deliberate trade-off:

- Suggestion 3: `setup.sh`'s `build_image()` can race when invoked twice
  in parallel (both pass the `image_exists` check, both call
  `podman build`). Podman serialises layer commits, so the worst case is
  duplicated work rather than corruption. Adding a `flock` is the right
  fix if this ever lands in CI; for a one-shot host-setup script the
  current shape is acceptable and matches acceptance criterion 1.

### Pass 2 - code-reviewer subagent (2026-05-13)

Pending re-run to confirm no regressions from the Pass 1 fixes.

## Out of scope

- arm64 support (the betterleaks and pnpm tarballs are amd64-only).
- A mise pin set in the image (would either land tools in `$HOME` or
  duplicate the baked tooling).
- A signed-commit pre-push hook in `templates/.pre-commit-config.yaml`.
  The host-side `git config commit.gpgsign true` setup in
  [INSTALL.md](INSTALL.md) is the documented alternative.
- A CI workflow that publishes the image to a registry. The image is
  built locally per host by design (no hosted registry trust chain).
