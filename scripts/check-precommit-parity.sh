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
# Exit codes follow sysexits.h conventions:
#   0  - configs match
#   1  - configs diverge (unified diff printed to stderr)
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

if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly _C_ERR=$'\e[1;31m'
  readonly _C_OFF=$'\e[0m'
else
  readonly _C_ERR=''
  readonly _C_OFF=''
fi

error() { printf '%s[ERROR]%s %s\n' "$_C_ERR" "$_C_OFF" "$*" >&2; }

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
  local line trimmed leading
  local in_local=0
  while IFS= read -r line; do
    # A `- repo: local` line opens a local-hook block; skip until the next
    # `- repo:` line (which clears the flag below).
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+repo:[[:space:]]+local[[:space:]]*$ ]]; then
      in_local=1
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+repo:[[:space:]]+ ]]; then
      in_local=0
    fi
    ((in_local)) && continue
    if [[ "$line" =~ ^[[:space:]]+(-[[:space:]]+)?(repo|rev):[[:space:]]+ ]]; then
      leading="${line%%[![:space:]]*}"
      trimmed="${line#"$leading"}"
      trimmed="${trimmed#- }"
      printf '%s\n' "$trimmed"
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
    --label "$(realpath --relative-to="$REPO_ROOT" "$ROOT_CFG")" \
    --label "$(realpath --relative-to="$REPO_ROOT" "$TPL_CFG")" \
    <(printf '%s\n' "$root_pins") \
    <(printf '%s\n' "$tpl_pins") >&2 || true
  exit 1
}

main "$@"
