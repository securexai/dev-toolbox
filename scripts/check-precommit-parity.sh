#!/usr/bin/env bash
#
# check-precommit-parity.sh - assert that the root .pre-commit-config.yaml and
# templates/.pre-commit-config.yaml share the same external (repo, rev) pin
# set, in the same order. Without this check, the dogfood gate and the gate
# that ships to downstream repos (via bootstrap-repo.sh) can silently drift
# apart on a hook revision bump.
#
# The two files intentionally differ in one place: the root config excludes
# 'templates/' from betterleaks. That divergence is on the `exclude:` field
# and does not show up in the (repo, rev) extraction here.
#
# `repo: local` blocks in the root config (e.g. this hook's own definition)
# are skipped — local hooks are repo-specific gates and are not expected to
# mirror into templates/.
#
# Usage:
#   ./scripts/check-precommit-parity.sh
#
# Env:
#   TRACE     - "1" enables bash xtrace
#   NO_COLOR  - any value suppresses ANSI colors
#
# Exit codes follow sysexits.h conventions:
#   0  - configs match
#   1  - configs diverge (unified diff printed to stderr) OR unsupported
#        YAML form encountered (bare '-' continuation list item)
#   66 - a config file is missing
#   69 - bash version too old

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
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly ROOT_CFG="${REPO_ROOT}/.pre-commit-config.yaml"
readonly TPL_CFG="${REPO_ROOT}/templates/.pre-commit-config.yaml"

# This is a checker: success is silent, failure is loud. No `log` or `warn`
# helpers — re-introduce the full setup.sh / bootstrap-repo.sh trio atomically
# with the first caller that needs them.
if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly _C_ERR=$'\e[1;31m'
  readonly _C_OFF=$'\e[0m'
else
  readonly _C_ERR=''
  readonly _C_OFF=''
fi

error() { printf '%s[ERROR]%s %s\n' "${_C_ERR}" "${_C_OFF}" "$*" >&2; }

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

extract_pins() {
  local file=$1
  local line value
  local emit=0
  while IFS= read -r line; do
    # Refuse the bare-`-` continuation list-item form (e.g. `-` on its own
    # line followed by `    repo: ...` on the next). It is valid YAML, but
    # pre-commit-autoupdate and every hand-written config in this repo uses
    # the inline `- repo: ...` form. Supporting both would require a real
    # YAML parser; failing loud is safer than silently mishandling drift.
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]*(#.*)?$ ]]; then
      die 1 "unsupported YAML form (bare '-' continuation) in ${file}: rewrite as inline '- repo: ...'"
    fi

    # Top-level list-item start: `  - repo: <value>`. Value captured up to
    # the first whitespace or `#` so trailing comments are stripped; quotes
    # around the value are stripped below.
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+repo:[[:space:]]+([^[:space:]#]+) ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value#[\"\']}"
      value="${value%[\"\']}"
      if [[ "$value" == "local" ]]; then
        emit=0
        continue
      fi
      emit=1
      printf 'repo: %s\n' "$value"
      continue
    fi

    # `rev:` key inside the current list item. Only emitted while tracking
    # an external (non-local) repo entry — the `emit` flag is reset by the
    # next `- repo:` line regardless of what came before, so a `local`
    # block can never leak its keys into the comparison.
    if ((emit)) && [[ "$line" =~ ^[[:space:]]+rev:[[:space:]]+([^[:space:]#]+) ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value#[\"\']}"
      value="${value%[\"\']}"
      printf 'rev: %s\n' "$value"
    fi
  done <"$file"
}

main() {
  [[ -f "$ROOT_CFG" ]] || die 66 "missing config: $ROOT_CFG"
  [[ -f "$TPL_CFG" ]]  || die 66 "missing config: $TPL_CFG"

  local root_pins tpl_pins
  root_pins="$(extract_pins "$ROOT_CFG")"
  tpl_pins="$(extract_pins "$TPL_CFG")"

  if [[ "$root_pins" == "$tpl_pins" ]]; then
    return 0
  fi

  error "pre-commit config parity check failed"
  error "root and templates configs declare different (repo, rev) pins:"
  diff -u \
    --label '.pre-commit-config.yaml' \
    --label 'templates/.pre-commit-config.yaml' \
    <(printf '%s\n' "$root_pins") \
    <(printf '%s\n' "$tpl_pins") >&2 || true
  exit 1
}

main "$@"
