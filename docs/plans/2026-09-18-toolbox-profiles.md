# Three Toolbox images

Record state: COMPLETED

## Approved baseline

- Outcome: local `dev-base`, `dev-python`, and `dev-infra` images and matching
  Toolbox containers, with documented setup and verification.
- Approval: user message, “proceed with 3 images standard”.
- Scope: image definitions, profile-aware setup, checks, and affected documentation.
- Constraints: preserve unrelated work, existing containers, repository hooks,
  infrastructure gates and credentials. No commits, publishing or deployments.
- Acceptance: build all three images; verify tools and writable container-local
  paths; validate setup failure handling and repeat runs; pass applicable static
  checks. Document blocked gates accurately.

## Tasks

| ID | Task / dependency | Progress | Gate / expected result | Gate status |
| --- | --- | --- | --- | --- |
| T01 | Base and two derived definitions | ✅ DONE | Build all three; tools report versions | ✅ PASS |
| T02 | Profile setup and verification; T01 | ✅ DONE | Correct selection, reuse, failure handling | ✅ PASS |
| T03 | Documentation and integration; T02 | ✅ DONE | Static checks and repository hook gate | ✅ PASS (see follow-up evidence) |

## Decisions and evidence

- Existing dirty tree inspected before edits. Most tracked changes are file modes;
  README also links unrelated host pnpm work, which must be preserved.
- Fedora 43 is retained. Fedora RPM versions may advance on rebuild; built image
  IDs and an installed RPM manifest provide the actual resolved inventory.
- Infrastructure starts with Python, YAML/network tools and Restic. Specialized
  infrastructure tools remain project-specific until tested; this does not migrate
  MikroTik away from its existing environment or authorize deployments.
- Initial Podman inspection was blocked by sandbox access to `/run/user/1000`;
  requested access to the rootless runtime for local validation.

## Validation evidence

Checks were performed in the dirty working tree on `main`, using host Bash 5.3.9
and rootless Podman. No commits or production changes were made.

- **Build PASS:** `./setup.sh infra --build-only` built base, Python and infra.
  Betterleaks 1.1.2 matched the configured SHA-256. The initial derived builds
  warned about an unused Fedora argument; the argument is now base-only.
  `REBUILD=1 ./setup.sh infra --build-only` then passed using cached layers with
  no unused-argument warnings. This verifies cached rebuilds, not fresh updates.
- **Runtime PASS:** created `dev-base`, `dev-python`, and `dev-infra`; ran
  `bash scripts/verify.sh <profile>` for all three. Normal-user directory writes,
  tool availability, clean-file scanning and generated synthetic-token detection
  passed. Python profiles passed offline virtual-environment and Ruff checks;
  infra also passed YAML parsing/linting and Restic availability.
- **Observed versions:** Python 3.14.7, uv 0.12.9, Ruff 0.16.6, pre-commit 4.6.2,
  ShellCheck 0.11.0, yamllint 1.38.0, Restic 0.19.1. Python differs from MikroTik's
  existing 3.13 declaration; no MikroTik compatibility or migration is claimed.
- **Setup PASS:** repeated real setup reused all three containers. The final
  `bash scripts/test-setup.sh` passed ordering, reuse, stale-container rejection,
  invalid input, failed build propagation, build-only mode, parent changes,
  custom names, parent-tag collision rejection and refresh rebuild selection.
  The explicit `REFRESH=1` network-refresh path was mock-tested, not executed
  against the live runtime; it passes `--no-cache` and pulls the Fedora base.
- **Bootstrap PASS:** a disposable repository under `/srv/work` received all six
  templates; repeat bootstrap preserved a local edit; `--force` restored the
  template. Hook environments, including commitlint, installed successfully.
  Empty-repository `pre-commit run --all-files` passed (file hooks skipped because
  there were no tracked files). Temporary test fixtures were removed afterward.
- **Static PASS:** Bash syntax, pinned `pnpm dlx shellcheck@4.1.0` over repository
  shell scripts, final image ShellCheck over changed scripts, pre-commit config
  validation, `scripts/check-precommit-parity.sh`, and `git diff --check` passed.
  The first ShellCheck attempt found a source-resolution warning; corrected and
  rerun successfully. The initial pnpm cache permission failure was resolved by
  approved runtime access.
- **Documentation PASS:** pinned markdownlint-cli2 0.22.1 on seven affected
  documents and hook version 0.18.1 passed. An initial duplicate changelog heading
  was corrected. Checked 20 local Markdown links and anchors for valid targets.
- **Repository hooks FAIL:** final `pre-commit run --files` covering all changed
  implementation files passed content, shell, Markdown, JSON and secret checks.
  Two hooks still fail: `no-commit-to-branch` on existing `main`, and
  `check-executables-have-shebangs` on eight pre-existing executable non-scripts
  (Containerfile, README, INSTALL, CLAUDE, CONTRIBUTING, CHANGELOG, PLAN and the
  Dev Container template). Initial EOF fixes in the new profile definitions were
  applied and verified. No required hook was skipped or weakened. A full-tree
  `--all-files` pass is not claimed; branch and mode blockers remain unresolved.

### Built image identities

| Profile | Image ID |
| --- | --- |
| base | `589bc35a3c68719a93757105bc18971193926b0eead4231833de20627d6b076f` |
| python | `bbe95ea5ffa4886a6ca721b6eafc734209fda74a4143df461d8c97b11becb442` |
| infra | `55e3617643783e958cfeb1e6f16af40f44aaafde9170779dd2b195d07425b698` |

The containers use these images. Each image includes its RPM manifest at
`/usr/share/dev-toolbox/rpm-manifest.txt`. Runtime checks establish the initial
development baseline, not deployment-tool compatibility or vulnerability status.
No image vulnerability scan or MikroTik offline suite was performed.

## Handoff

### Fedora 44 update

- User requested the base container use Fedora 44. The profile release setting,
  default profile tags, Dev Container template, setup comments, behavioral tests
  and current documentation now use Fedora 44. Historical Fedora 43 evidence and
  image IDs remain historical and are not evidence for this update.
- Required validation: build and runtime verification for all three Fedora 44
  profiles, setup behavioral tests, and relevant hooks. Record new image IDs and
  results before closing this update.
- **Build PASS:** `REFRESH=1 ./setup.sh infra --build-only` pulled Fedora 44,
  rebuilt the base without cache, and built both derived profiles. Betterleaks
  1.1.2 passed its configured SHA-256 verification.
- **Runtime PASS:** created isolated validation containers `dev-base-44`,
  `dev-python-44`, and `dev-infra-44` without replacing the Fedora 43
  containers. `scripts/verify.sh` passed for each profile: normal-user paths,
  tools, synthetic secret detection, offline Python/Ruff checks, and applicable
  YAML/Restic checks passed. Observed Python 3.14.7, uv 0.12.9, Ruff 0.16.6,
  ShellCheck 0.11.0, yamllint 1.38.0 and Restic 0.19.1.
- **Image IDs:** base `b82aa0f9088a11bfdab70af73a7f45a58149d9d11c0037fd831ac0484195ce15`,
  Python `fa2c9fa02fbe31e050528f2c628152fe0a011c6b8e19fb5873995c6d7fda1eb0`,
  infra `7d2aff394c43946a893ef551d403fa32128464f5be2e2cc449789531252973e2`.
- **Checks PASS:** `bash scripts/test-setup.sh`, `git diff --check`, full-tree
  `pre-commit run --all-files`, and an explicit hook run for the changed and
  untracked Fedora 44 definitions passed inside `dev-base-44`.
- The Fedora 43 images and `dev-base`, `dev-python`, and `dev-infra` containers
  remain available for rollback. The Fedora 44 validation containers are
  `dev-base-44`, `dev-python-44`, and `dev-infra-44`.

### Authorized validation follow-up

- User approved next steps “1 and 2”: create a feature branch, correct the eight
  identified executable non-script modes, run the full hook gate, and review the
  final diff. No commit, push or MikroTik migration is authorized.
- Resumed after checking branch, status, exact implementation diff and prior
  evidence. Created `codex/toolbox-profiles` and corrected the eight modes.
- First full-tree hook attempt failed on nine additional non-script executable
  flags: `.gitignore`, `.markdownlint-cli2.yaml`, `.pre-commit-config.yaml`,
  `LICENSE`, `templates/.editorconfig`, `templates/.pre-commit-config.yaml`,
  `templates/commitlint.config.js`, `templates/.betterleaks.toml`, and
  `templates/.markdownlint-cli2.yaml`. Inspection confirmed mode-only differences
  from Git's recorded `100644`. Corrected the same defect without content changes.
- **Full gate PASS:** `toolbox run --container dev-base pre-commit run --all-files`
  exited 0; every configured pre-commit-stage hook passed, including branch
  protection, executable checks, secrets, ShellCheck, Markdown and hook parity.
- **New files PASS:** an explicit `pre-commit run --files` covered `.containerignore`,
  `versions.env`, both profile definitions, both profile scripts and this execution
  record, because `--all-files` only includes tracked files. All applicable hooks
  passed. Existing unrelated untracked work was preserved.
- **Diff review PASS:** reviewed tracked implementation/documentation changes and
  new profile files; no additional blocking findings. `git diff --check` passed.
  Only modes and this record changed during the follow-up; earlier build/runtime
  results remain applicable. No commit was made and no commit-msg check is claimed.

- Current outcome: all three images built, containers created, setup and runtime
  tests passed; documentation updated; full pre-commit gate passed on the feature
  branch after correcting 17 non-script file modes.
- Remaining gates: none for the approved three-profile implementation and
  validation follow-up. The previously documented compatibility and scan limits
  remain; MikroTik trials are separate work.
- Exact next action: user review of the uncommitted result. Commit, push and
  MikroTik migration require separate authorization.
- Final state: COMPLETED.
