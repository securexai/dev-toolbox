# Contributing to dev-toolbox

Thanks for taking the time to read this. dev-toolbox is small and the
contribution path is intentionally short.

## Development environment

Dogfood the toolbox you are working on:

```bash
./setup.sh
toolbox enter dev
cd /srv/work
git clone <fork-of-this-repo> dev-toolbox
cd dev-toolbox
pre-commit install --install-hooks
```

All scripts assume Bash 5.3+. Inside the toolbox, `bash --version` should
report 5.3.x or newer (Fedora 43 and 44 default).

## Coding standards

- **Bash scripts** follow the bash-standards skill: strict-mode preamble
  (`errexit`, `nounset`, `pipefail`, `errtrace`, `inherit_errexit`,
  `nullglob`), version guard, XDG paths where applicable, sysexits-style
  exit codes, and ShellCheck-clean output.
- **Markdown docs** follow the doc-standards skill: one H1 per file, ATX
  headings, language-tagged fenced code blocks, descriptive links,
  consistent table column counts, and meaningful alt text for images.
- **Conventional Commits** with the type list in
  `templates/commitlint.config.js`. Subject line ≤72 characters, imperative
  mood, no trailing period.

## Pre-commit gates

The repo runs its own pre-commit baseline:

| Hook | Stage | What it blocks |
| --- | --- | --- |
| pre-commit-hooks (hygiene) | pre-commit | trailing whitespace, EOL drift, merge markers, large files |
| betterleaks | pre-commit | hardcoded secrets |
| no-commit-to-branch (`main`, `master`, `develop`, `release/*`) | pre-commit | direct commits to protected branches |
| shellcheck | pre-commit | shell lint violations |
| markdownlint-cli2 | pre-commit | markdown lint violations |
| precommit-config-parity (local) | pre-commit | drift between root and `templates/` `.pre-commit-config.yaml` pin sets |
| commitlint | commit-msg | non-conventional commit messages |

Run the whole gate manually before pushing:

```bash
pre-commit run --all-files
```

## Pull request checklist

- [ ] Branch name reflects the change (`feat/...`, `fix/...`, `docs/...`).
- [ ] Commits use Conventional Commits.
- [ ] `pre-commit run --all-files` exits 0.
- [ ] Static validators pass:
      `pnpm dlx markdownlint-cli2@0.22.1 --no-globs **/*.md` and
      `pnpm dlx shellcheck@4.1.0 setup.sh bootstrap-repo.sh scripts/*.sh`.
- [ ] If the Containerfile changed, a rebuild succeeds:
      `REBUILD=1 ./setup.sh`.
- [ ] `CHANGELOG.md` `[Unreleased]` updated under the relevant heading.
- [ ] [PLAN.md](PLAN.md) iteration log updated if the change responds to a
      code-reviewer finding.

## Out of scope

- arm64 / aarch64 — the betterleaks and pnpm release tarballs ship amd64
  only. Add an arm64 branch in the Containerfile if a fork needs it.
- Non-Fedora hosts — the image is `fedora-toolbox:43` and the install
  guide assumes Fedora `toolbox`. Other distros need their own equivalent.
- A hosted registry build / publish pipeline. The image is built locally
  on every host by design.
