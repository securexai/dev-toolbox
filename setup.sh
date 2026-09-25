#!/usr/bin/env bash
#
# setup.sh - Build a development profile and create its Toolbox
# container. Idempotent: safe to re-run. Set REBUILD=1 to force an image
# rebuild.
#
# Usage:
#   ./setup.sh [base|python|infra] [--build-only]
#   REBUILD=1 ./setup.sh    # rebuild image even if present
#   TRACE=1   ./setup.sh    # bash -x trace through the script
#
# Env:
#   REBUILD         - "1" forces podman build even if image exists
#   REFRESH         - "1" also pulls the Fedora base and disables build cache
#   TRACE           - "1" enables bash xtrace
#   NO_COLOR        - any value suppresses ANSI colors in log output
#   BUILD_NETWORK   - podman build network backend (default: slirp4netns to
#                     work around a Fedora passt-selinux AVC; override to
#                     "pasta" once the policy ships upstream)
#   IMAGE_REF       - override final image (default: localhost/dev-PROFILE:fedora-44)
#   CONTAINER_NAME  - override container name (default: dev-PROFILE)

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
# Release settings are validated separately; hooks lint this script in isolation.
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/versions.env"
PROFILE=base
BUILD_ONLY=0

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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 \
    || die 69 "required command not found on PATH: $1"
}

container_exists() {
  podman container exists "${CONTAINER_NAME}"
}

build_image() {
  local profile=$1 image=$2 parent=${3:-} containerfile parent_id=''
  local -a args=()
  containerfile="${SCRIPT_DIR}/Containerfile"
  if [[ "$profile" != base ]]; then
    containerfile="${SCRIPT_DIR}/profiles/Containerfile.${profile}"
    parent_id=$(podman image inspect --format '{{.Id}}' "$parent")
    args+=(--build-arg "BASE_IMAGE=${parent_id}" --pull=never
      --label "io.dev-toolbox.parent-id=${parent_id}")
  else
    args+=(--build-arg "FEDORA_RELEASE=${FEDORA_RELEASE}")
    if [[ "${REFRESH:-0}" == 1 ]]; then args+=(--pull=always); fi
  fi
  if [[ "${REFRESH:-0}" == 1 ]]; then args+=(--no-cache); fi
  if podman image exists "$image" && [[ "${REBUILD:-0}" != 1 && "${REFRESH:-0}" != 1 ]] &&
    { [[ "$profile" == base ]] ||
      [[ $(podman image inspect --format '{{index .Labels "io.dev-toolbox.parent-id"}}' "$image") == "$parent_id" ]]; }; then
    log "image ${image} already present (set REBUILD=1 to rebuild changed definitions)"
    return 0
  fi
  log "building ${image} from ${containerfile}"
  # slirp4netns sidesteps the F43 passt-selinux AVC; override to pasta once
  # selinux-policy ships the fix.
  podman build \
    --network "${BUILD_NETWORK:-slirp4netns}" \
    "${args[@]}" \
    --tag "${image}" \
    --file "${containerfile}" \
    "${SCRIPT_DIR}"
  podman image exists "$image" \
    || die 70 "build reported success but image ${image} is not present"
}

create_container() {
  if container_exists; then
    local expected actual
    expected=$(podman image inspect --format '{{.Id}}' "$IMAGE_REF")
    actual=$(podman container inspect --format '{{.Image}}' "$CONTAINER_NAME")
    [[ "$expected" == "$actual" ]] ||
      die 70 "container '${CONTAINER_NAME}' uses an older/different image. Preserve its work and choose a new CONTAINER_NAME."
    log "toolbox container '${CONTAINER_NAME}' already exists"
    return 0
  fi
  log "creating toolbox '${CONTAINER_NAME}' from ${IMAGE_REF}"
  toolbox create --image "${IMAGE_REF}" --container "${CONTAINER_NAME}"
  container_exists \
    || die 70 "toolbox create succeeded but container '${CONTAINER_NAME}' is not listed"
  log "toolbox '${CONTAINER_NAME}' ready"
}

main() {
  case "${1:-base}" in
    -h|--help)
      printf 'Usage: %s [base|python|infra] [--build-only]\n' "$0"
      return 0 ;;
    base|python|infra) PROFILE=${1:-base} ;;
    *) die 64 "unknown profile: $1 (choose base, python or infra)" ;;
  esac
  if (($# > 0)); then shift; fi
  if [[ "${1:-}" == --build-only ]]; then BUILD_ONLY=1; shift; fi
  (($# == 0)) || die 64 "unexpected argument: $1"
  readonly PROFILE BUILD_ONLY
  IMAGE_REF=${IMAGE_REF:-localhost/dev-${PROFILE}:fedora-${FEDORA_RELEASE}}
  CONTAINER_NAME=${CONTAINER_NAME:-dev-${PROFILE}}
  readonly IMAGE_REF CONTAINER_NAME
  require_cmd podman
  if ((BUILD_ONLY == 0)); then require_cmd toolbox; fi
  local base_ref="localhost/dev-base:fedora-${FEDORA_RELEASE}"
  local python_ref="localhost/dev-python:fedora-${FEDORA_RELEASE}"
  if [[ "$PROFILE" != base && "$IMAGE_REF" == "$base_ref" ]] ||
    [[ "$PROFILE" == infra && "$IMAGE_REF" == "$python_ref" ]]; then
    die 64 "IMAGE_REF must not overwrite a parent profile tag"
  fi
  if [[ "$PROFILE" == base ]]; then base_ref=$IMAGE_REF; fi
  if [[ "$PROFILE" == python ]]; then python_ref=$IMAGE_REF; fi
  build_image base "$base_ref"
  if [[ "$PROFILE" != base ]]; then build_image python "$python_ref" "$base_ref"; fi
  if [[ "$PROFILE" == infra ]]; then build_image infra "$IMAGE_REF" "$python_ref"; fi
  if ((BUILD_ONLY)); then return 0; fi
  create_container

  log "done. enter the toolbox with:"
  printf '        toolbox enter %s\n' "${CONTAINER_NAME}" >&2
  log "then clone a repo under ~/code/repos and run ./bootstrap-repo.sh --target ~/code/repos/<repo>"
}

main "$@"
