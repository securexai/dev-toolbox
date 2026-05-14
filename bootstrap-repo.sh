#!/usr/bin/env bash
#
# bootstrap-repo.sh - Drop the dev-toolbox enforcement templates into a target
# git repository and wire pre-commit. Intended to run INSIDE the dev-toolbox
# (or any container where pre-commit, betterleaks, commitlint, shellcheck,
# markdownlint-cli2 are already on PATH).
#
# Idempotent: re-running skips files that already exist unless --force is set.
#
# Usage:
#   ./bootstrap-repo.sh [--force] [--target <path>]
#
# Defaults:
#   --target $PWD
#
# Env:
#   TRACE       - "1" enables bash xtrace
#   NO_COLOR    - any value suppresses ANSI colors

if ((BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3))); then
  printf 'ERROR: This script requires Bash 5.3+. Current: %s\n' "$BASH_VERSION" >&2
  exit 69
fi

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s nullglob

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly TEMPLATES_DIR="${SCRIPT_DIR}/templates"

if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly _C_INFO=$'\e[1;34m'
  readonly _C_WARN=$'\e[1;33m'
  readonly _C_ERR=$'\e[1;31m'
  readonly _C_OFF=$'\e[0m'
else
  readonly _C_INFO=''
  readonly _C_WARN=''
  readonly _C_ERR=''
  readonly _C_OFF=''
fi

log()   { printf '%s[INFO]%s  %s\n' "${_C_INFO}" "${_C_OFF}" "$*" >&2; }
warn()  { printf '%s[WARN]%s  %s\n' "${_C_WARN}" "${_C_OFF}" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "${_C_ERR}"  "${_C_OFF}" "$*" >&2; }

die() {
  local code=${1:-1}
  shift || true
  error "$@"
  exit "$code"
}

on_error() {
  local code=$?
  local line=${1:-?}
  local command=${2:-?}
  printf 'ERROR: %s:%s: %q exited %d\n' \
    "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}" "$line" "$command" "$code" >&2
  return "$code"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

[[ "${TRACE:-0}" == "1" ]] && set -o xtrace

usage() {
  cat <<'EOF'
bootstrap-repo.sh - drop enforcement templates into a target git repo.

Usage:
  bootstrap-repo.sh [--force] [--target <path>]

Defaults:
  --target $PWD

Flags:
  --force        Overwrite files that already exist.
  --target PATH  Target git worktree (must contain a .git entry).
  -h, --help     Show this help.
EOF
}

target="${PWD}"
force=0
while (( $# > 0 )); do
  case "$1" in
    --force)
      force=1
      shift
      ;;
    --target)
      [[ $# -ge 2 ]] || die 64 "--target requires a path argument"
      target="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die 64 "unknown argument: $1 (see --help)"
      ;;
  esac
done

orig_target="${target}"
target="$(cd -- "${target}" 2>/dev/null && pwd)" \
  || die 66 "target not a directory: ${orig_target}"
[[ -e "${target}/.git" ]] \
  || die 66 "target is not a git worktree (no .git entry): ${target}"

log "target: ${target}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 \
    || die 69 "required command not found on PATH: $1 (run inside dev-toolbox)"
}

require_cmd pre-commit
require_cmd git

copy_template() {
  local src="$1"
  local dst="$2"
  local rel="${dst#"${target}/"}"
  [[ -e "${src}" ]] || die 70 "template missing: ${src}"
  if [[ -e "${dst}" ]] && (( force == 0 )); then
    warn "exists, skipping: ${rel} (pass --force to overwrite)"
    return 0
  fi
  install -D -m 0644 "${src}" "${dst}"
  log "wrote: ${rel}"
}

copy_template "${TEMPLATES_DIR}/.pre-commit-config.yaml"      "${target}/.pre-commit-config.yaml"
copy_template "${TEMPLATES_DIR}/.betterleaks.toml"            "${target}/.betterleaks.toml"
copy_template "${TEMPLATES_DIR}/commitlint.config.js"         "${target}/commitlint.config.js"
copy_template "${TEMPLATES_DIR}/.markdownlint-cli2.yaml"      "${target}/.markdownlint-cli2.yaml"
copy_template "${TEMPLATES_DIR}/.editorconfig"                "${target}/.editorconfig"
copy_template "${TEMPLATES_DIR}/.devcontainer/devcontainer.json" \
              "${target}/.devcontainer/devcontainer.json"

log "wiring pre-commit hooks (pre-commit + commit-msg stages)"
(
  cd "${target}"
  pre-commit install --install-hooks
)

log "done."
log "next:"
log "  cd ${target}"
log "  pre-commit run --all-files      # warm cache + audit current tree"
log "  git add <new files>"
log "  git commit -m 'chore: bootstrap dev-toolbox enforcement baseline'"
