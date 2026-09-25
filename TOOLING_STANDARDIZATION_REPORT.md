# Tooling Standardization Report: dev-toolbox and mikrotik

**Assessment date:** September 15, 2026 (America/Bogota).  
**Target:** one Fedora Kinoite workstation and its MikroTik/Hermes infrastructure workflows.  
**Preference:** open source first; dependable operation, reproducibility, and low maintenance.  
**Deliverable:** assessment and adoption recommendations; no tooling or infrastructure changes performed.

## 1. Executive summary

**Keep the useful foundations in both repositories and standardize their quality gates and update policy first.**
The largest immediate gains come from correcting inconsistent versions, incomplete secret scanning, and stale
onboarding instructions. Replacing every tool would add migration work without resolving these problems.

Recommended direction:

- **Keep Podman and Toolbx** for Fedora-native, disposable development environments.
- **Keep Nix/Devbox for mikrotik's declared tool environment.** Its lockfile is valuable, but its workstation
  bootstrap currently targets retired infrastructure. Repair that path before expanding adoption.
- **Use the pre-commit configuration format as the shared target for Git quality gates.** Keep the existing
  runners during migration; retain mikrotik's specialized checks. Trial **prek** as a compatible execution
  alternative after behavior and cache-location checks pass.
- **Keep ShellCheck, shfmt, markdownlint-cli2, uv, and pnpm in their existing roles.** Add explicit version
  alignment and Ruff checks for mikrotik's Python code. Do not add application frameworks to these repositories.
- **Replace mikrotik's handwritten secret detector with the shared Betterleaks baseline**, after validating
  current configuration compatibility and synthetic fixtures. Retain Gitleaks as the fallback candidate.
- **Keep Hermes' existing operational tools and evidence gates.** Add image/dependency assessment to the
  toolbox workflow, and verify scanner artifacts. Do not infer production readiness from earlier lab passes.
- **Trial VSCodium and OpenCode**, while retaining working VS Code/Codex workflows until the trials demonstrate
  equivalent integration and acceptable task results.

These are fit-based recommendations, not a claim that one product is universally the industry gold standard.
The comparison criteria and supporting evidence follow below.

### Priority decisions

| Priority | Decision | Expected benefit | Main tradeoff |
| --- | --- | --- | --- |
| First | Repair mikrotik onboarding to use its active root configuration | A fresh setup installs the intended toolchain | Requires regression checks around existing Nix/SELinux handling |
| First | Replace broad secret-scan exclusions and the grep gate | Consistent coverage of scripts, RouterOS, and Markdown | Rules and fixtures need tuning to avoid false positives |
| First | Record exact gate/runtime versions and separate install from update | Repeatable checks and controlled upgrades | More deliberate dependency maintenance |
| Next | Align hook policies, then migrate mikrotik's runner | One policy with preserved project-specific tests | Hook installation and stage behavior must be migrated together |
| Next | Add read-only CI checks and image provenance records | Reviewable, repeatable evidence outside local hooks | CI setup and runtime cost |
| Later | Trial alternative editor and AI clients | Greater openness and provider flexibility | Extension compatibility, model quality, and training effort |

## 2. Method, scope, and evidence

### Evidence labels

- **Configured:** directly observed in the working-tree files linked below.
- **Recorded:** documented by the repository, without a fresh live verification.
- **Observed:** checked in this assessment's local execution environment.
- **Recommended:** an engineering judgment based on the inspected workflows and cited upstream information.
- **Unverified:** unavailable or outside this assessment; never treated as a passing result.

Both working trees already contained changes. This report evaluates those working trees, not just committed
HEAD. The recorded HEADs were:

| Repository | HEAD | Primary role |
| --- | --- | --- |
| dev-toolbox | 151c1b47537f1cbb0f5f478c8b9894040ea985b9 | Container image and reusable repository-enforcement templates |
| mikrotik | 59a226dcf062fa5388e538f4188a2dad96e1b296 | Network configuration, Hermes deployment tooling, workstation setup, and tests |

Inspection covered repository guidance, manifests and lockfiles, setup scripts, hook definitions, test
entrypoints, editor templates, and Hermes' evidence/deployment records. Sensitive private artifacts and live
devices were not inspected. Repository links are absolute paths for this workstation; they require adjustment
if the report is moved elsewhere.

**Observed environment:** Fedora Kinoite 44.20260913.0, Bash 5.3.9, and Toolbx reporting version 0.3.
Podman exists on PATH, but even its version command could not initialize its runtime configuration because
the session could not create /run/user/1000/libpod. Devbox, Nix, pre-commit, Lefthook, ShellCheck, shfmt,
markdownlint-cli2, and uv were not on this session's PATH; /nix/store was absent in the visible filesystem.
These observations describe this execution context, not every container or session on the workstation.

### Definition of a good standard

Evaluate candidates in this order:

1. Correct behavior for the actual Fedora, RouterOS, and Hermes workflows.
2. Reproducible versions, trustworthy distribution, and useful failure diagnostics.
3. Open licensing, interoperable formats, and an achievable exit path.
4. Maintenance effort, integration quality, and migration cost.
5. Performance and convenience demonstrated on representative tasks.

No synthetic numeric ranking is assigned: cold-start times, false-positive rates, and AI task success were
not measured. Upstream performance claims are not workstation benchmarks. Current release observations are
listed separately from repository pins; a newer release is a trial candidate, not an automatically approved upgrade.

## 3. Current inventory

### 3.1 dev-toolbox

Sources: [image definition][d-image], [root hooks][d-hooks], [downstream hooks][d-template-hooks],
[setup][d-setup], [bootstrap][d-bootstrap], and [README][d-readme]. All entries below are **configured**.

| Tool or capability | Version/installation policy | Role and relevant limitation |
| --- | --- | --- |
| Fedora Toolbx image | fedora-toolbox:43 tag; local Podman build | Tag is not a content digest; base content can change between builds |
| Podman / Toolbx | Host prerequisites; not pinned by this repository | Create and enter the disposable development container |
| Bash | Scripts require 5.3+ | Explicit runtime contract; image package version is not independently fixed |
| Git, gh, Python, Node, jq, ripgrep | Fedora dnf packages | Useful base tooling; resolution follows repositories at build time |
| pre-commit | Fedora dnf package | Runner version floats with image build; hook revisions are separately pinned |
| uv | 0.11.8, versioned upstream installer | Installer is fetched at build time; no explicit installer checksum in this file |
| Ruff | uv tool install without a version | Available as an image tool; no Ruff hook in the inspected baseline |
| Betterleaks | Binary 1.1.2 with SHA-256; hook v1.1.2 | Existing scanner and reusable custom rules |
| pnpm | 11.0.3 archive with SHA-256 | Installs ad-hoc Node CLIs; image also installs Fedora Node |
| commitlint | Image global floats; hook dependencies 19.5.0 | Wrapper hook v9.22.0; rules file exists in templates |
| markdownlint-cli2 | Image global floats; hook v0.18.1 | Contributor instructions separately reference 0.22.1 |
| ShellCheck | Fedora image package; shellcheck-py hook v0.10.0.1 | Wrapper revision is distinct from the underlying ShellCheck version |
| shfmt | Fedora package | Installed, but no shfmt gate in the inspected hook configuration |
| pre-commit-hooks | v6.0.0 | Hygiene, syntax, private-key checks, and protected-branch checks |
| Editor integration | VS Code extension IDs, unpinned | Dev Containers template; EditorConfig copied to consumers |
| Baseline consistency | check-precommit-parity.sh | Compares external repository/revision pairs, not every argument or dependency |

The root hook configuration and downstream template intentionally differ. They should share approved tool
versions without becoming identical files. The root excludes templates from Betterleaks; the downstream
scanner configuration also excludes fixture directories and files ending in .lock. Those exclusions need
review before this becomes a broader standard. See [scanner rules][d-secrets] and [parity checker][d-parity].

### 3.2 mikrotik

Sources: [Devbox manifest][m-devbox], [Devbox lockfile][m-lock], [hooks][m-hooks],
[contributor guide][m-contrib], and [workstation setup][m-setup].

| Tool or capability | Configured or recorded version | Role and evidence status |
| --- | --- | --- |
| Nix / Determinate installer | Guide records Determinate Nix 3.17.2 / Nix 2.33.3 | Recorded Fedora 43 setup; installer and host adjustments are in setup.sh |
| Devbox | Guide records 0.17.1; schema URL references 0.17.0 | Schema version is not an installed CLI version |
| Lefthook | latest selector resolves to 2.1.1 in lockfile | Configured pre-commit, commit-msg, and pre-push stages |
| markdownlint-cli2 | latest resolves to 0.21.0 | Staged-file hook uses --no-globs; project configuration enables fixes |
| ShellCheck | latest resolves to 0.11.0 | Configured shell diagnostics |
| shfmt | latest resolves to 3.13.1 | Configured formatting check; excludes ShellSpec files |
| ShellSpec | latest resolves to 0.28.1 | Existing Hermes/controller and VM contract tests |
| HTML Tidy | 5.8.0 | Declared tool for HTML documentation |
| Restic | 0.19.1 | Declared backup/recovery tool in the Hermes toolchain |
| Trivy | 0.74.0 | Declared vulnerability scanner; deployment policy and evidence are separate |
| systemd / systemdUkify | 259.3 | Declared advanced host/boot tooling; does not prove host systemd version |
| sbsigntool | 0.9.5 | Advanced boot verification tooling |
| virt-firmware / PyYAML | Python 3.13 packages, 25.12 / 6.0.3 | Declared firmware/configuration dependencies |
| Python unittest / shell tests | Repository test files | Existing offline checks; root Devbox test script runs only RouterOS and Nix-guide checks |
| Secret detector | Inline grep pipeline | Added staged lines only, with Markdown excluded |
| Conventional Commits | Inline regular expression | Less extensive policy than dev-toolbox's commitlint template |
| SSH / Podman / libvirt-QEMU | Host/integration dependencies | Documented for operations and optional tests; not all managed by root Devbox |
| AI/editor guidance | AGENTS.md, CLAUDE.md, and IDE/provider documentation | Workflow guidance exists; installed products and subscriptions were not inventoried |

**Important:** latest selectors do not mean every Devbox run installs today's latest package. The checked-in
lockfile records concrete versions and Nixpkgs revisions. Explicit updates can move those resolutions.
The issue is update discipline and bootstrap behavior, not the mere presence of the word latest.
[Jetify's package-pinning documentation][s-devbox-pins] explains that distinction.

### 3.3 Active software versus retained history

| Component | Evidence | Treatment in the standard |
| --- | --- | --- |
| RB5009 RouterOS configuration | Script version 2.6.19; header says tested on RouterOS 7.23.3 | Keep native .rsc workflow and its safety/idempotency checks; live firmware unverified |
| CRS310 RouterOS configuration | Script version 2.6.9; header says tested on RouterOS 7.22.1 | Keep device-specific validation; script versions are not firmware versions |
| Hermes Fedora Server tooling | Multiple implementation profiles and dated candidate evidence | Preserve profile-specific acceptance and promotion gates |
| Simplified Hermes application profile | September 12 plan and simple controller entrypoint exist | Planned/in-progress in inspected records; not a certified production deployment |
| Advanced TPM/UKI profile | Dependencies, code, and historical lab results remain | Specialized/deferred work; do not make it a general workstation prerequisite |
| Talos/Kubernetes and former LGTM stack | README states decommissioned in August 2026 | Historical; exclude from the active default tool installation |

Sources: [router header][m-router], [switch header][m-switch], [README][m-readme],
[Hermes verification ledger][m-evidence], [ordered deployment gates][m-gates],
[profile execution record][m-profile], and [simple entrypoint][m-simple].

Neither checkout contains .github/workflows files or the inspected common root GitLab/Jenkins/Woodpecker
configuration names. That establishes a **checkout-level CI gap**, not proof that no external CI exists.
mikrotik has a GitHub origin; dev-toolbox had no origin configured in this checkout.

## 4. Findings that should drive standardization

### F1. Rebuilds and interactive commands do not currently reproduce one complete toolchain

dev-toolbox combines a mutable base tag, unfixed dnf resolutions, floating ad-hoc tools, and separately pinned
hooks. For example, markdownlint uses a floating image binary, a 0.18.1 hook, and a 0.22.1 documented command.
The existing parity checker does not compare image tools, documentation commands, or additional_dependencies.
These differences are partly intentional, but they prevent a general claim that every execution path is identical.
[Evidence: image][d-image], [hooks][d-hooks], [contributor commands][d-contrib], [parity][d-parity].

**Recommendation:** record the image digest and installed package manifest for each approved build; explicitly
pin ad-hoc tools; select one approved version per checking role. Have interactive commands and hooks use that
version, or document the exception. A base digest alone does not freeze subsequent dnf/package downloads.
An approved built artifact and its inventory provide a stronger reference than a local image tag.

### F2. Active workstation setup still installs the historical Talos environment

mikrotik's install_project_packages function points at kubernetes/talos, then performs both install and update.
Its setup help and Nix guide also describe Talos/kubectl/Helm as project tools. This conflicts with the active
root manifest and the decommissioning statement. The setup script also contains real host modifications for
composefs, Nix services, ownership, and SELinux. [Setup][m-setup], [Nix guide][m-nix], [active scope][m-readme].

**Recommendation:** make the root manifest the default; preserve historical setup only as an explicit archival
workflow. Separate installation from dependency updates. Revalidate the Fedora 43 workarounds on Fedora 44
before retaining or removing them; do not assume the old workaround is still necessary or safely removable.

### F3. Secret detection is inconsistent and has broad blind spots

mikrotik excludes all Markdown from its staged-line detector and relies on a small assignment-pattern regex.
The pipeline also does not explicitly propagate every upstream command failure. dev-toolbox has a dedicated
scanner, but broad template, fixture, and lockfile exclusions can hide unintended credentials.
[MikroTik hooks][m-hooks], [toolbox hooks][d-hooks], [scanner configuration][d-secrets].

**Recommendation:** share the Betterleaks policy; cover staged content, maintained documentation, and a separate
history scan. Replace directory-wide exemptions with narrowly justified exceptions where possible. Require
nonzero status for scanner/configuration failures. Keep validation local and disable credential-verification
network requests for the default gate. Betterleaks supports verification requests, so detection and live
credential testing must be treated as separate features. [Betterleaks upstream][s-betterleaks].

### F4. Blindly bootstrapping mikrotik can conflict with its hook owner

dev-toolbox's bootstrap installs pre-commit hooks. mikrotik's Devbox initialization forcibly installs Lefthook
and suppresses installation errors. Both can manage the same Git hook locations. This is an installation
conflict risk established by the configurations; no destructive reproduction was attempted.
[Bootstrap][d-bootstrap], [Devbox initialization][m-devbox].

**Recommendation:** one hook owner per repository at a time. Migrate configuration, installer, and stage
coverage together. Preserve branch protection, commit checks, and all four existing pre-push test commands.
Do not install the toolbox template into mikrotik unchanged.

### F5. Omitting workspaceMount does not establish the Dev Containers disposal guarantee

The dev-toolbox README suggests that leaving workspaceMount out preserves container-local source storage.
VS Code documents automatic source bind mounting when an image or Dockerfile is specified. Therefore the
template omission does not prove the claimed behavior for Reopen in Container. Attaching to the existing
Toolbx and explicitly opening /srv/work is the clearer supported workflow.
[Local template][d-devcontainer], [local explanation][d-readme], [VS Code mount behavior][s-source-mount].

**Recommendation:** validate mounts in a disposable fixture and correct the guarantee. Keep distinct
acceptance tests for Attach and Reopen. A named volume also has a different lifetime from the container overlay.
Toolbx additionally exposes substantial host resources; its convenience integration is not a security boundary
for untrusted code or an unrestricted AI agent. [Toolbx documentation][s-toolbx].

### F6. Installed tools, invoked gates, and documented checks are different sets

dev-toolbox installs Ruff and shfmt but does not enforce them in its inspected baseline. mikrotik has substantial
Python code and tests, yet no Ruff gate in its current hooks. Its default Devbox test script omits Hermes tests
that its pre-push hook does run. Both Markdown configurations enable fixes, which is unsuitable for a check
that promises not to rewrite files. [Toolbox hooks][d-hooks], [MikroTik hooks][m-hooks],
[Devbox scripts][m-devbox], [toolbox Markdown config][d-markdown], [MikroTik Markdown config][m-markdown].

**Recommendation:** publish an explicit check matrix, provide read-only check commands and separate fix
commands, and add Python/shell formatting checks where the code exists. Adopt changes without bulk reformatting
historical evidence. Confirm root commitlint configuration discovery: the inspected rules file is in templates,
so its existence alone does not prove that the root commit-msg gate loads it.

### F7. Current scanner selection needs an artifact-trust policy

Trivy's maintainers documented a March 2026 compromise affecting distribution infrastructure, including a
malicious 0.69.4 release and Docker Hub tags 0.69.5/0.69.6. They describe credential resets, pipeline hardening,
and provenance improvements. This does **not** establish that mikrotik's locked 0.74.0 artifact is compromised.
[Maintainer incident conclusion, March 30, 2026][s-trivy-incident].

**Recommendation:** keep the scanner interface and existing evidence contract, but verify the exact selected
artifact, provenance, and policy/database versions before approving it for a new build. Use Grype as a trial
cross-check for selected images; disagreement requires investigation, not automatic acceptance of the smaller
finding count. [Trivy][s-trivy], [Grype][s-grype].

### F8. Hermes readiness must be read at the profile and candidate level

The README's broad healthy/certified description is not sufficient evidence for every current profile. The
canonical records retain failures, stale candidate evidence, open production gates, and a newer simplified
profile. Passing an offline suite or a previous VM run is not production acceptance for changed inputs.
[Verification ledger][m-evidence], [task gates][m-gates], [profile record][m-profile].

**Recommendation:** keep those gates and make profile, candidate identity, and evidence date visible in tooling
reports. Tool consolidation must not erase compatibility entrypoints, promotion fingerprints, or recovery checks.

## 5. Comparison with current alternatives

The following tables distinguish product capability from the recommended fit. Effort estimates are qualitative;
no migration or performance benchmark was executed.

### 5.1 Environments and hook systems

| Candidate | Pros | Cons | Fedora/workflow fit | Decision |
| --- | --- | --- | --- | --- |
| Toolbx + Podman | Fedora integration; OCI images; preserves the current disposable workspace design | Mutable builds need additional discipline; host integration is extensive | Strong default for dev-toolbox | **Keep**; fix version and mount evidence. [Toolbx][s-toolbx] |
| Devbox + Nix | Locks concrete package resolutions; broad system-tool coverage; existing mikrotik configuration | Nix store/services persist; current Kinoite bootstrap has host-specific complexity | Strong for mikrotik's mixed tooling; incompatible with a promise of zero persistent host setup | **Keep** as the infrastructure profile; repair onboarding. [Devbox][s-devbox], [pinning][s-devbox-pins] |
| mise | Combines runtime selection, environment variables, and tasks | Another manager to support; cannot replace the image or OS/boot qualification contract | Attractive for a future language-centric repository | **Trial only if a concrete unmet runtime need appears**. [mise][s-mise] |
| pre-commit | Existing reusable configuration and hook ecosystem; manages hook environments | Extra environments/cache; cold setup and runtime provisioning add complexity | Lowest migration distance from the toolbox's current baseline | **Keep; adopt its configuration format as the shared target**. [Documentation][s-precommit] |
| Lefthook | Parallel commands and flexible stage orchestration; already integrated with Devbox | Commands depend on the surrounding tool environment; a second policy file can drift | Useful existing mikrotik implementation | **Keep during migration; replace only after equivalent checks pass**. [Lefthook][s-lefthook] |
| prek | Pre-commit-compatible configuration; single executable; upstream supports shared toolchains | Compatibility and cache behavior still need a local trial; performance gains are unmeasured here | Promising execution replacement without rewriting policy | **Trial**, then replace the runner only on acceptance. [prek][s-prek] |

**Chosen architecture:** two deliberate environment profiles, one shared quality policy. Do not put Nix inside
Toolbx by default or install all environment managers on every machine. Their benefits solve different problems.

**Hook migration endpoint:** pre-commit-format configuration in both repositories, with infrastructure checks
remaining local to mikrotik. pre-commit is the initial reference runner. prek becomes the preferred runner only
if the trial preserves diagnostics, exit status, staged-file handling, all stages, and container-local caches.
Otherwise retain pre-commit; maintain no permanent double installation of runners in Git hook paths.

### 5.2 Formatting, testing, scanning, and dependencies

| Capability | Existing choices and credible alternatives | Pros and cons of the preferred choice | Recommendation |
| --- | --- | --- | --- |
| Shell diagnostics / formatting | ShellCheck + shfmt; handwritten grep/style rules | Dedicated diagnostics and formatting already fit the code; formatting changes can create large diffs | **Keep** ShellCheck/shfmt; add the missing toolbox format gate, retain ShellSpec exclusions. [ShellCheck][s-shellcheck], [shfmt][s-shfmt] |
| Python lint / format | Ruff; separate formatter/linter combinations | One tool can cover many style checks; neither linting nor formatting replaces tests or type analysis | **Add** Ruff to maintained mikrotik Python code; **keep optional** in the generic toolbox. [Ruff][s-ruff] |
| Python environment management | uv; existing Devbox Python; pip/venv | uv provides project locking; forcing it onto dependency-light operational scripts adds another manifest | **Keep** uv for Python projects and tooling; preserve Devbox runtime ownership for current infrastructure scripts. [uv][s-uv], [locking][s-uv-lock] |
| JavaScript package management | pnpm; npm; Bun as an additional runtime/package option | pnpm already serves CLI tooling and supports frozen installs; it does not eliminate separate runtime requirements | **Keep** pnpm where needed; no Bun migration or new JS application stack justified. [pnpm install][s-pnpm] |
| Markdown | markdownlint-cli2; broader prose/style platforms | Both repos already use the same linter; versions, HTML rules, and fix behavior differ | **Keep**; align versions and read-only check behavior. [markdownlint-cli2][s-markdownlint] |
| Commit messages | commitlint; mikrotik regex | commitlint supports a more explicit shared policy; adds a Node tool dependency | **Keep/Add** the existing commitlint policy after testing merge/revert handling and root config discovery. [Template][d-commitlint] |
| Shell/controller tests | ShellSpec; existing shell tests; alternative Bats-style suites | Existing test investments have direct value; framework conversion creates work without increasing coverage | **Keep** existing suites; add missing failure cases instead of rewriting them. [ShellSpec][s-shellspec] |
| Secret detection | Betterleaks; Gitleaks; existing grep | Betterleaks already has custom RouterOS rules and current upstream development; upgrades can affect configuration behavior | **Keep/upgrade after trial** in dev-toolbox; **replace grep** in mikrotik. Gitleaks is fallback if fixtures or packaging fail. [Betterleaks][s-betterleaks], [Gitleaks][s-gitleaks] |
| Vulnerabilities / software inventory | Trivy; Grype | Existing Hermes integration favors Trivy; distribution trust, advisory freshness, and coverage need explicit evidence | **Keep** verified Trivy; **add** toolbox image assessment; **trial** Grype as a cross-check. [Trivy][s-trivy], [SBOM support][s-sbom], [Grype][s-grype] |
| Container definition quality | Hadolint; manual review | Adds structured Dockerfile/Containerfile rules and embedded shell checks; Fedora-specific exceptions need explanation | **Add** Hadolint for the toolbox and test Containerfiles. [Hadolint][s-hadolint] |
| Documentation links | Lychee; existing Hermes link script | General Markdown/HTML checking complements domain checks; rate limits and private URLs need careful exclusions | **Add** Lychee for public/maintained docs; **keep** Hermes-specific checks. [Lychee][s-lychee] |

No root application manifest was found in either repository. These are principally tooling/infrastructure
repositories, with Python implementation code in mikrotik. Introducing a web framework, frontend test stack,
monorepo build system, or a new type checker without a specific need would increase maintenance.

### 5.3 Editors, terminal workflow, and AI assistants

| Candidate | Pros | Cons | Recommendation |
| --- | --- | --- | --- |
| VS Code + Dev Containers | Already documented; existing extension IDs and attachment workflow | Distributed product has Microsoft terms; open-source code does not make every extension/distribution open | **Keep** as the compatibility baseline during trials. [License distinction][s-vscode-license], [template][d-devcontainer] |
| VSCodium | MIT-licensed binaries; Linux RPM/Flatpak options; similar editor workflow | Extension availability/licensing and container attachment must be demonstrated for the selected build | **Trial** as the open-source GUI default; adopt only if the actual six extensions and attachment flow work. [VSCodium][s-vscodium] |
| Neovim | Can run directly in a terminal/container; extensive programmability | Modal editing and plugin maintenance impose learning/setup costs | **Optional** terminal editor, not a mandatory GUI replacement. [Neovim][s-neovim] |
| Codex CLI | Open-source local client; Linux terminal workflow; existing session provides a usable baseline | Hosted inference has separate terms and usage cost; client openness does not establish model openness | **Keep** as a baseline/optional provider choice, without declaring it the universal winner. [Official CLI documentation][s-codex] |
| OpenCode | MIT client; provider selection supports avoiding one mandatory vendor | Model quality/cost remain provider-specific; repository controls need a real task trial | **Trial** as the first additional open-source terminal agent. [OpenCode][s-opencode], [providers][s-opencode-providers] |
| Continue | Apache-2.0 client; configurable IDE/CLI and local-model workflows | Adds another integration; local quality and hardware suitability are unmeasured | **Optional trial** only if in-editor assistance is needed. [Continue][s-continue], [offline setup][s-continue-offline] |

Keep the existing terminal and Bash 5.3 script contract. Git, jq, and ripgrep remain the common command-line
baseline. There is no measured bottleneck that justifies replacing the user's interactive shell or terminal.
Claude/Antigravity references in repository guidance are not evidence that those products are required or
installed; this report does not add another subscription.

For AI trials, use the same bounded tasks: explain a RouterOS diff, modify a shell helper against fixtures,
repair a Python test, improve a document, and review a change for regressions. Record accepted results,
reviewer corrections, elapsed time, actual usage cost, and unauthorized-action attempts. Keep deterministic
tests as the acceptance authority. Do not allow an agent's self-assessment to certify a deployment.

### 5.4 Infrastructure software, CI, and maintenance

| Area | Preferred approach | Alternatives and tradeoffs | Decision |
| --- | --- | --- | --- |
| Router/switch automation | Existing .rsc and verified SSH workflows | Ansible community.routeros helps with inventory/scale; API modules introduce prerequisites, and generic API operations are not automatically idempotent | **Keep** current workflow; **trial Ansible only when scale warrants it**, without enabling APIs as a side effect. [Ansible API module][s-routeros-ansible] |
| Hermes service operation | Existing Fedora/Podman/systemd approach and profile-specific controller | Reintroducing Kubernetes adds orchestration and migration cost for the current scope | **Keep**; Quadlet is an appropriate future declarative container-service option if needed, not a required controller rewrite. [Podman Quadlet][s-quadlet], [profile][m-profile] |
| Backup and recovery | Restic and existing semantic restoration gates | Alternative backup engines require revalidating format, retention, permissions, and recovery | **Keep** Restic; prioritize restore evidence and key handling over product replacement. [Restic][s-restic], [restore][s-restic-restore] |
| VM qualification | Existing libvirt/QEMU and repository acceptance contracts | Containers cannot establish hardware/boot/TPM acceptance | **Keep project-specific**; preserve the documented direct-hypervisor exception. [VM guide][m-vm] |
| Logs and operational checks | Existing systemd journal, health checks, evidence ledger | A new centralized observability stack adds services and retention duties | **Keep lightweight defaults**; do not reactivate the retired LGTM stack without a measured need. [Active scope][m-readme], [Quadlet][s-quadlet] |
| CI | Repository-owned validation commands run on clean CI workers | GitHub Actions fits mikrotik's origin but is a hosted-service dependency; another forge would mean migration | **Add** validation-only CI; keep checks usable locally and choose dev-toolbox's remote before enabling hosted workflows. [GitHub secure-use guidance][s-ci-security] |
| CI workflow validation | actionlint | Manual YAML review misses expression/type issues | **Add with CI**, not before workflows exist. [actionlint][s-actionlint] |
| Dependency updates | Renovate-generated proposals, reviewed before merging | Manual updates are simpler initially; Dependabot is a credible GitHub-centric alternative, but coverage must match the actual manifests | **Add after CI**; Renovate has a documented Devbox manager. [Renovate][s-renovate], [Devbox manager][s-renovate-devbox] |

GitHub Actions is a pragmatic hosting choice, not an open-source service requirement. Run open-source checking
tools behind repository-owned commands so hosting can change. Pin third-party actions to verified full commit
SHAs and avoid giving pull-request validation production access. [GitHub guidance][s-ci-security].

## 6. Licensing and maintenance snapshot

### 6.1 License boundaries

Licenses below describe the upstream projects, not every transitive dependency, extension, hosted service,
or AI model. This is a selection aid, not a complete redistributed-image license inventory.

| Project or group | Verified license position | Selection implication |
| --- | --- | --- |
| Devbox / Nix core | Devbox Apache-2.0; upstream and Determinate Nix core LGPL-2.1 | Open core tooling; review installer, ancillary services, and hosted features separately. [Devbox][s-devbox], [Nix core][s-nix-license] |
| prek / Betterleaks | MIT | Suitable open-source candidates. [prek][s-prek], [Betterleaks][s-betterleaks] |
| uv | MIT or Apache-2.0 | Open-source Python tooling. [uv][s-uv] |
| shfmt / ShellSpec / markdownlint-cli2 | BSD-3-Clause / MIT / MIT | Compatible with the intended local tooling model. [shfmt][s-shfmt], [ShellSpec][s-shellspec], [Markdown][s-markdownlint] |
| Hadolint / actionlint | GPL-3.0 / MIT | Open-source validators; account for licenses if redistributing tools. [Hadolint][s-hadolint], [actionlint][s-actionlint] |
| Trivy / Restic | Apache-2.0 / BSD-2-Clause | No proprietary scanner/backup client required. [Trivy][s-trivy], [Restic][s-restic] |
| Renovate | AGPL-3.0 | Self-hosting is available; hosting and operational effort still have a cost. [Renovate][s-renovate] |
| VSCodium / VS Code distribution | MIT binaries / separate Microsoft product terms | Test the open alternative while preserving required integration. [VSCodium][s-vscodium], [VS Code license][s-vscode-license] |
| OpenCode / Continue / Codex CLI | MIT / Apache-2.0 / documented open-source client | Model licenses, provider processing, and usage charges are separate decisions. [OpenCode][s-opencode], [Continue][s-continue], [Codex][s-codex] |

RouterOS remains the existing vendor platform. Open-source-first tooling does not require replacing the
router's operating system or hardware. Fedora is a distribution of separately licensed packages; preserve an
inventory when distributing a built toolbox image.

### 6.2 Current release observations

These are upstream pages retrieved on the assessment date. They are **not** new pins applied to either repo.
Release caches can lag: prek's latest endpoint initially returned 0.5.2, while its directly opened 0.5.3 page
confirmed a newer September 13 release. Use a specific verified release page when preparing an actual upgrade.

| Tool | Repository baseline | Upstream observation | Recommended treatment |
| --- | --- | --- | --- |
| uv | 0.11.8 | [0.12.15, September 15][r-uv] | Active release stream; test upgrade and pin the selected artifact |
| Ruff | Floating image install; no inspected gate | [0.16.7, September 10][r-ruff] | Pin a tested version and introduce checks incrementally |
| pnpm | 11.0.3 | [12.4.2 release][r-pnpm] | Major-version jump; do not silently adopt during a rebuild |
| pre-commit | dnf-resolved runner | [4.6.2, August 10][r-precommit] | Record/pin the approved runner independently of hook revisions |
| Lefthook | Locked 2.1.1 | [2.1.14 release][r-lefthook] | Maintenance continues; replacement is a consolidation choice, not an abandonment claim |
| prek | Not configured | [0.5.3, September 13][r-prek] | Current trial candidate; upstream compatibility claims need local acceptance |
| Betterleaks | 1.1.2 | [1.8.1, August 18][r-betterleaks] | Upgrade trial needed; validate custom config and default rules |
| Restic | Locked 0.19.1 | [Stable documentation identifies 0.19.1][s-restic-restore] | No upgrade justified merely to appear newer |
| markdownlint-cli2 | 0.18.1 hook / 0.21.0 Devbox / 0.22.1 documented | [Maintained upstream documentation][s-markdownlint]; current release number not established reliably | Resolve and test one version before changing all invocation paths |
| Devbox / Trivy | Recorded CLI 0.17.1 / locked scanner 0.74.0 | Current official documentation and upstream repositories inspected | Latest patch not established here; verify exact artifacts during adoption |

The source set establishes available maintained projects and current functionality, not a complete maintainer
capacity or security audit. There is no evidence here that changing to an older, better-known scanner would
automatically improve detection, or that a faster hook runner would materially shorten this user's workflow.

## 7. Proposed shared standard

### Environment and ownership

| Layer | Default and owner | Required exception or boundary |
| --- | --- | --- |
| Workstation | Fedora-supported host components; operator owns OS, Podman, SSH, and virtualization | Nix host integration belongs to the infrastructure profile and needs its own validated setup |
| Disposable development | dev-toolbox owns image definition, package inventory, and /srv/work lifecycle | Keep deliberate identity/editor sharing; verify actual mounts and all tool caches |
| Infrastructure development | mikrotik owns root devbox.json/devbox.lock and domain tests | Preserve direct-hypervisor operations as documented; do not nest additional managers by default |
| Shared quality policy | dev-toolbox owns versioned baseline templates and common rule intent | mikrotik owns its local tests, exclusions, deployment contracts, and rollout timing |
| Application dependencies | Project manifest and lockfile when a real application needs them | Devbox owns system-tool selection; uv/pnpm own their respective application dependencies |
| Operational service | mikrotik owns profile-specific configuration, image identity, and evidence | A developer tool update cannot implicitly approve a production promotion |

### Version and update policy

- Publish a small approved-tool matrix with exact versions, source URLs, integrity evidence, and check commands.
  Keep it separate from a software bill of materials for the full image.
- Pin image content by digest and capture resolved RPMs and installed tools. Test reproducible tool versions
  across clean builds; do not claim bit-for-bit image reproducibility without measuring it.
- Commit Devbox lock changes deliberately. A normal setup should install the reviewed lock, not run update.
- Use locked/frozen application installs where application manifests exist. uv's --locked option checks lock
  freshness without rewriting it; pnpm supports frozen lockfile installs. [uv][s-uv-lock], [pnpm][s-pnpm].
- Start with a monthly grouped maintenance review. Triage security advisories promptly; schedule major version
  changes separately. This cadence is a recommendation, not an automation created by this assessment.
- Keep the previous approved image/tool policy available until the replacement passes its acceptance checks.

### Consistent developer interface

Provide the same documented tasks in both repositories: check formatting, lint, scan secrets, run offline tests,
and report tool versions. The implementation can use existing scripts and the selected hook runner; adding a
new task-runner product is unnecessary. Fix commands must be separate and explicit.

For shared checks, use the same approved tool versions and intended rule sets. Preserve meaningful exceptions:
ShellSpec formatting exclusions, RouterOS semantics, Hermes profile gates, and frozen historical evidence.
Keep formatting exclusions distinct from secret-scan scope; an archived file can still contain a leaked secret.

## 8. Adoption roadmap and rollback

Effort is an estimate for one maintainer, excluding downloads, remote approvals, and the existing Hermes
certification campaign. Complete one phase before expanding scope.

| Phase | Changes | Dependency and acceptance | Effort | Rollback |
| --- | --- | --- | --- | --- |
| 1. Correct the baseline | Repair active setup target; separate install/update; record tool matrix; correct workspace-mount documentation | Fresh setup selects root Devbox packages; environment/version inventory is reproducible; tests distinguish Attach/Reopen | 0.5–1.5 days | Restore prior configuration/guide revision; retain prior image; avoid uninstalling working host services |
| 2. Close coverage gaps | Trial Betterleaks upgrade; replace grep; narrow allowlists; add read-only shfmt/Ruff/Hadolint checks | Positive and negative fixtures pass; scanner errors fail closed; old domain tests still pass | 1–2 days | Restore previous runner and versions; retain any newly validated security checks independently |
| 3. Align hook ownership | Port mikrotik policy to pre-commit format; preserve pre-push tests; remove forced conflicting installer only at cutover | Fresh clone, staged/unstaged changes, commit-msg, and pre-push fixtures behave correctly | 1–2 days | Restore Lefthook config/installer and verify all hook stages; retain the shared rule specification |
| 4. Establish CI evidence | Run shared read-only checks in clean workers; add actionlint and public-link checks; produce toolbox inventory/scan results | Local/CI versions match; no production credentials or device access; fixed artifact retained for comparison | 1–2 days | Disable new workflow while keeping local validation; restore previous approved artifact |
| 5. Automate reviewed updates | Configure Renovate after CI; group routine updates; keep major/toolchain changes separate | A sample proposal updates the intended manifest and lockfile, then passes checks | 0.5–1 day | Disable update job; return to the documented manual review cadence |
| 6. Trial optional clients | Benchmark prek, then VSCodium/OpenCode only where useful | Equivalent hook behavior; working editor extensions/attachment; acceptable AI task results and cost | Time-box each trial to 0.5–1 day | Keep the existing runner/editor/client and remove only the trial configuration |

**Migrations explicitly excluded from this roadmap:** automatic RouterOS firmware upgrades, hardware changes,
production deployment, OS/TPM/firmware redesign, reactivation of Kubernetes/LGTM, and new recurring automations.
Existing Hermes SIMPLE/UA/B gates remain authoritative for their own profiles.

## 9. Acceptance checks and assessment validation

### 9.1 Proposed adoption checks — not executed

| Scenario | Expected result |
| --- | --- |
| Clean workstation/bootstrap fixture | Active root Devbox manifest selected; routine install leaves reviewed locks unchanged; no Talos tools installed by default |
| Clean toolbox builds | Same approved checking-tool versions; recorded image digest and package inventory; changed dependencies are visible |
| Disposable workspace | Deleting only the test container removes its overlay workspace and designated caches; intentional host identity/editor data remains |
| Dev Containers Attach versus Reopen | Inspect both mount sets; the documented source-storage/lifetime claim matches each tested flow |
| Hook ownership and partial staging | Only the selected runner installs hooks; no unrelated files modified or restaged; invalid staged content fails |
| Commit policy and branch controls | Valid messages pass; invalid messages fail; intended merge/revert handling and protected-branch behavior survive migration |
| Secret fixtures | Synthetic secrets in .sh, .rsc, .md, and previously excluded locations are detected as intended; valid placeholders pass; malformed config/missing scanner fails |
| Scanner upgrade | Exact artifact and integrity evidence recorded; compare fixture coverage and image findings against the previous approved scanner/policy |
| Formatting/lint parity | Same files, versions, and rules produce equivalent local/CI results; check mode does not rewrite content |
| Backup/restore fixture | Restore application data into an isolated target and verify semantic behavior, permissions, and credential exclusions |
| Editor trial | Each required extension works in the chosen build; lint/debug commands execute in the intended environment; container attachment succeeds |
| AI trial | Same bounded tasks and budget; human-accepted output passes checks; no unauthorized external or production action |

Existing commands to preserve in the adoption test matrix include:

| Repository | Existing check | Purpose |
| --- | --- | --- |
| dev-toolbox | ./scripts/check-precommit-parity.sh | External hook revision consistency |
| dev-toolbox | pre-commit run --all-files | Full baseline; contains fixing hooks, so run in a disposable validation checkout |
| mikrotik | devbox run -- ./tests/test-routeros.sh | Offline RouterOS text/configuration checks, not a live RouterOS runtime test |
| mikrotik | devbox run -- ./tests/test-nix-guide.sh | Workstation-guide contract |
| mikrotik | devbox run -- ./tests/test-hermes-guide.sh | Hermes documentation contract |
| mikrotik | devbox run -- shellspec spec/hermes/ spec/vm/ | Controller and VM contracts |
| mikrotik | devbox run -- ./tests/test-sshd-unit.sh | SSH unit behavior |
| mikrotik | Relevant existing Python unittest files under tests/ | Select by changed Hermes/SSH component; no replacement of live certification |

Run Devbox commands only in a provisioned environment and inspect initialization first: the current init hook
installs Lefthook. Optional container/VM checks remain separate because they create resources or change test
hosts. Use the [contributor guide][m-contrib] and [VM guide][m-vm] to select them.

### 9.2 Checks performed for this report

- Inspected both working trees and their relevant source/configuration files; parsed the Devbox JSON/lock data.
- Compared actual image, hook, lockfile, and documented version policies.
- Confirmed the absence of the inspected CI files and root application manifests.
- Retrieved authoritative product documentation, repositories, release pages, and the Trivy incident statement.
- Checked the visible OS, Bash and Toolbx versions, tool availability, and the Podman initialization limitation.
- Validated this report's headings, table structure, reference links, local file targets, whitespace, and line layout.
- Compared before/after Git diff fingerprints and status so the report is the only new repository change.

**Not performed:** project test suites, hook installation, image builds, software installation, live network/SSH
checks, credential scanning of private data, restore operations, performance benchmarks, or production
certification. markdownlint-cli2 was unavailable and was not installed; structural checks do not constitute a
full markdownlint run. External citations were retrieved during research, not exhaustively tested by a separate
HTTP link-checking service.

## 10. Remaining uncertainties and final recommendation

- The session's tool availability may differ from the user's normal shell or containers. Inventory those during
  adoption before deciding anything is missing from the actual workstation.
- Exact installed tool versions, image digests, live RouterOS versions, and current Hermes runtime health were
  not verified. Repository versions and old evidence are not substitutes.
- Current Fedora 44 requirements for the Nix/composefs workaround require a disposable-host qualification.
- Direct release observations are a dated snapshot. Several tools' latest patches and the full transitive license
  inventory remain unestablished; verify them before changing pins.
- VSCodium extension compatibility, AI model quality, local-model hardware suitability, and usage costs need trials.
- Hosted CI permissions/billing and dev-toolbox's intended remote are unverified. They do not block local standards.

**Adopt now as policy:** active-component onboarding, exact version records, shared check semantics, dedicated
secret scanning, explicit hook ownership, and evidence-bound operational acceptance.

**Trial next:** Betterleaks upgrade, prek, VSCodium, and OpenCode, in that order of relevance to existing gaps.
Introduce CI and reviewed dependency automation after the baseline checks are consistent.

**Keep project-specific:** Devbox's infrastructure profile, RouterOS checks and transport, ShellSpec conventions,
Hermes controllers, encrypted backup/recovery, virtualization requirements, and certification gates.

## 11. Source index

Local evidence links resolve to the inspected working trees. Upstream links point to documentation or source
owners; recommendation language elsewhere in this report is the assessment's judgment. All upstream sources
were consulted on September 15, 2026. Exact-release links are preferred where available.

### Local evidence

- dev-toolbox: [README][d-readme], [image][d-image], [setup][d-setup], [bootstrap][d-bootstrap],
  [root hooks][d-hooks], [downstream hooks][d-template-hooks], [scanner rules][d-secrets],
  [Dev Containers template][d-devcontainer], [contributor guide][d-contrib], [parity checker][d-parity],
  [Markdown configuration][d-markdown], [commitlint rules][d-commitlint].
- mikrotik: [README][m-readme], [working rules][m-agents], [Devbox manifest][m-devbox], [lockfile][m-lock],
  [hooks][m-hooks], [setup][m-setup], [Nix guide][m-nix], [contributor guide][m-contrib],
  [Markdown configuration][m-markdown], [router][m-router], [switch][m-switch], [VM guide][m-vm],
  [Hermes evidence][m-evidence], [deployment gates][m-gates], [profile record][m-profile],
  [simple deployment entrypoint][m-simple].

### Upstream sources

- Environments and hooks: [Toolbx][s-toolbx], [Devbox][s-devbox], [Devbox pinning][s-devbox-pins],
  [Nix core licensing][s-nix-license], [mise][s-mise], [pre-commit][s-precommit],
  [Lefthook][s-lefthook], [prek][s-prek].
- Quality tools: [ShellCheck][s-shellcheck], [shfmt][s-shfmt], [ShellSpec][s-shellspec], [uv][s-uv],
  [uv locking][s-uv-lock], [Ruff][s-ruff], [pnpm][s-pnpm], [Markdown lint][s-markdownlint],
  [Hadolint][s-hadolint], [Lychee][s-lychee].
- Security and operations: [Betterleaks][s-betterleaks], [Gitleaks][s-gitleaks], [Trivy][s-trivy],
  [Trivy incident][s-trivy-incident], [SBOM scanning][s-sbom], [Grype][s-grype], [Restic][s-restic],
  [restore documentation][s-restic-restore], [Ansible RouterOS][s-routeros-ansible], [Quadlet][s-quadlet].
- Editors and AI: [VS Code licensing][s-vscode-license], [source mount behavior][s-source-mount],
  [VSCodium][s-vscodium], [Neovim][s-neovim], [Codex CLI][s-codex], [OpenCode][s-opencode],
  [OpenCode providers][s-opencode-providers], [Continue][s-continue], [Continue offline][s-continue-offline].
- CI and updates: [GitHub secure use][s-ci-security], [actionlint][s-actionlint], [Renovate][s-renovate],
  [Renovate Devbox manager][s-renovate-devbox].

[d-readme]: /var/home/aicloudopspecial/code/repos/dev-toolbox/README.md
[d-image]: /var/home/aicloudopspecial/code/repos/dev-toolbox/Containerfile
[d-setup]: /var/home/aicloudopspecial/code/repos/dev-toolbox/setup.sh
[d-bootstrap]: /var/home/aicloudopspecial/code/repos/dev-toolbox/bootstrap-repo.sh
[d-hooks]: /var/home/aicloudopspecial/code/repos/dev-toolbox/.pre-commit-config.yaml
[d-template-hooks]: /var/home/aicloudopspecial/code/repos/dev-toolbox/templates/.pre-commit-config.yaml
[d-secrets]: /var/home/aicloudopspecial/code/repos/dev-toolbox/templates/.betterleaks.toml
[d-devcontainer]: /var/home/aicloudopspecial/code/repos/dev-toolbox/templates/.devcontainer/devcontainer.json
[d-contrib]: /var/home/aicloudopspecial/code/repos/dev-toolbox/CONTRIBUTING.md
[d-parity]: /var/home/aicloudopspecial/code/repos/dev-toolbox/scripts/check-precommit-parity.sh
[d-markdown]: /var/home/aicloudopspecial/code/repos/dev-toolbox/.markdownlint-cli2.yaml
[d-commitlint]: /var/home/aicloudopspecial/code/repos/dev-toolbox/templates/commitlint.config.js
[m-readme]: /var/home/aicloudopspecial/code/repos/mikrotik/README.md
[m-agents]: /var/home/aicloudopspecial/code/repos/mikrotik/AGENTS.md
[m-devbox]: /var/home/aicloudopspecial/code/repos/mikrotik/devbox.json
[m-lock]: /var/home/aicloudopspecial/code/repos/mikrotik/devbox.lock
[m-hooks]: /var/home/aicloudopspecial/code/repos/mikrotik/lefthook.yml
[m-setup]: /var/home/aicloudopspecial/code/repos/mikrotik/setup.sh
[m-nix]: /var/home/aicloudopspecial/code/repos/mikrotik/docs/NIX_INSTALL_GUIDE.md
[m-contrib]: /var/home/aicloudopspecial/code/repos/mikrotik/docs/CONTRIBUTING.md
[m-markdown]: /var/home/aicloudopspecial/code/repos/mikrotik/.markdownlint-cli2.yaml
[m-router]: /var/home/aicloudopspecial/code/repos/mikrotik/network/router/rb5009.rsc
[m-switch]: /var/home/aicloudopspecial/code/repos/mikrotik/network/switch/crs310.rsc
[m-vm]: /var/home/aicloudopspecial/code/repos/mikrotik/docs/VM_TESTING_GUIDE.md
[m-evidence]: /var/home/aicloudopspecial/code/repos/mikrotik/docs/HERMES_INSTALLATION_VERIFICATION.md
[m-gates]: /var/home/aicloudopspecial/code/repos/mikrotik/vm/DEPLOYMENT_TASKS.md
[m-profile]: /var/home/aicloudopspecial/code/repos/mikrotik/docs/plans/2026-09-07-hermes-unattended.md
[m-simple]: /var/home/aicloudopspecial/code/repos/mikrotik/hermes-simple-deploy.sh
[s-toolbx]: https://github.com/containers/containertoolbx.org/blob/main/doc.md
[s-devbox]: https://github.com/jetify-com/devbox
[s-devbox-pins]: https://www.jetify.com/docs/devbox/guides/pinning-packages
[s-nix-license]: https://github.com/DeterminateSystems/nix-src
[s-mise]: https://mise.jdx.dev/
[s-precommit]: https://pre-commit.com/
[s-lefthook]: https://github.com/evilmartians/lefthook
[s-prek]: https://github.com/j178/prek
[s-shellcheck]: https://github.com/koalaman/shellcheck
[s-shfmt]: https://github.com/mvdan/sh
[s-shellspec]: https://github.com/shellspec/shellspec
[s-uv]: https://github.com/astral-sh/uv
[s-uv-lock]: https://docs.astral.sh/uv/concepts/projects/sync/
[s-ruff]: https://docs.astral.sh/ruff/
[s-pnpm]: https://pnpm.io/cli/install
[s-markdownlint]: https://github.com/DavidAnson/markdownlint-cli2
[s-hadolint]: https://github.com/hadolint/hadolint
[s-lychee]: https://github.com/lycheeverse/lychee
[s-betterleaks]: https://github.com/betterleaks/betterleaks
[s-gitleaks]: https://github.com/gitleaks/gitleaks
[s-trivy]: https://github.com/aquasecurity/trivy
[s-trivy-incident]: https://github.com/aquasecurity/trivy/discussions/10462
[s-sbom]: https://trivy.dev/docs/latest/guide/target/sbom/
[s-grype]: https://github.com/anchore/grype
[s-restic]: https://github.com/restic/restic
[s-restic-restore]: https://restic.readthedocs.io/en/stable/050_restore.html
[s-routeros-ansible]: https://docs.ansible.com/projects/ansible/latest/collections/community/routeros/api_module.html
[s-quadlet]: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
[s-vscode-license]: https://code.visualstudio.com/license
[s-source-mount]: https://code.visualstudio.com/remote/advancedcontainers/change-default-source-mount
[s-vscodium]: https://vscodium.com/
[s-neovim]: https://github.com/neovim/neovim
[s-codex]: https://learn.chatgpt.com/docs/codex/cli
[s-opencode]: https://github.com/anomalyco/opencode
[s-opencode-providers]: https://opencode.ai/docs/providers/
[s-continue]: https://github.com/continuedev/continue
[s-continue-offline]: https://docs.continue.dev/guides/running-continue-without-internet
[s-ci-security]: https://docs.github.com/en/actions/reference/security/secure-use
[s-actionlint]: https://github.com/rhysd/actionlint
[s-renovate]: https://github.com/renovatebot/renovate
[s-renovate-devbox]: https://docs.renovatebot.com/modules/manager/devbox/
[r-uv]: https://github.com/astral-sh/uv/releases/tag/0.12.15
[r-ruff]: https://github.com/astral-sh/ruff/releases/tag/0.16.7
[r-pnpm]: https://github.com/pnpm/pnpm/releases/tag/v12.4.2
[r-precommit]: https://github.com/pre-commit/pre-commit/releases/tag/v4.6.2
[r-lefthook]: https://github.com/evilmartians/lefthook/releases/tag/v2.1.14
[r-prek]: https://github.com/j178/prek/releases/tag/v0.5.3
[r-betterleaks]: https://github.com/betterleaks/betterleaks/releases/tag/v1.8.1
