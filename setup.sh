#!/usr/bin/env bash
#
# setup.sh - Build the pinned dev-toolbox image and create the `dev` toolbox
# container. Idempotent: safe to re-run. Set REBUILD=1 to force an image
# rebuild.
#
# Usage:
#   ./setup.sh              # build if missing, create container if missing
#   REBUILD=1 ./setup.sh    # rebuild image even if present
#   TRACE=1   ./setup.sh    # bash -x trace through the script
#
# Env:
#   REBUILD         - "1" forces podman build even if image exists
#   TRACE           - "1" enables bash xtrace
#   NO_COLOR        - any value suppresses ANSI colors in log output
#   BUILD_NETWORK   - podman build network backend (default: slirp4netns to
#                     work around Fedora 43 passt-selinux AVC; override to
#                     "pasta" once the policy ships upstream)
#   IMAGE_REF       - override image reference (default: localhost/dev-toolbox:fedora-43)
#   CONTAINER_NAME  - override container name (default: dev)

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
readonly CONTAINERFILE="${SCRIPT_DIR}/Containerfile"
readonly IMAGE_REF="${IMAGE_REF:-localhost/dev-toolbox:fedora-43}"
readonly CONTAINER_NAME="${CONTAINER_NAME:-dev}"

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

image_exists() {
  podman image exists "${IMAGE_REF}"
}

container_exists() {
  podman container exists "${CONTAINER_NAME}"
}

build_image() {
  if image_exists && [[ "${REBUILD:-0}" != "1" ]]; then
    log "image ${IMAGE_REF} already present (set REBUILD=1 to force rebuild)"
    return 0
  fi
  log "building ${IMAGE_REF} from ${CONTAINERFILE}"
  # slirp4netns sidesteps the F43 passt-selinux AVC; override to pasta once
  # selinux-policy ships the fix.
  podman build \
    --network "${BUILD_NETWORK:-slirp4netns}" \
    --tag "${IMAGE_REF}" \
    --file "${CONTAINERFILE}" \
    "${SCRIPT_DIR}"
  image_exists \
    || die 70 "build reported success but image ${IMAGE_REF} is not present"
  log "image ${IMAGE_REF} ready"
}

create_container() {
  if container_exists; then
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
  require_cmd podman
  require_cmd toolbox
  [[ -f "${CONTAINERFILE}" ]] \
    || die 66 "Containerfile not found: ${CONTAINERFILE}"

  build_image
  create_container

  log "done. enter the toolbox with:"
  printf '        toolbox enter %s\n' "${CONTAINER_NAME}" >&2
  log "then clone a repo under /srv/work and run ./bootstrap-repo.sh /srv/work/<repo>"
}

main "$@"
