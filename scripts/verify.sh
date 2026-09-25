#!/usr/bin/env bash
# Run offline checks inside an existing Toolbx, using its regular host UID.
if ((BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3))); then
  printf 'ERROR: Bash 5.3+ required\n' >&2
  exit 69
fi
set -Eeuo pipefail
shopt -s inherit_errexit nullglob
trap 'printf "ERROR: verification failed at line %s\n" "$LINENO" >&2' ERR
profile=${1:-base}
case "$profile" in base|python|infra) ;; *) exit 64 ;; esac
(($# <= 2)) || exit 64
toolbox run --container "${2:-dev-${profile}}" bash -s -- "$profile" <<'CHECKS'
set -Eeuo pipefail
profile=$1
test "$(id -u)" -ne 0
for tool in git gh curl ssh jq rg make pre-commit shellcheck shfmt betterleaks; do
  command -v "$tool" >/dev/null
done
pre-commit --version
shellcheck --version
betterleaks version
test -s /usr/share/dev-toolbox/rpm-manifest.txt
for dir in "$PRE_COMMIT_HOME" "$UV_TOOL_DIR" "$UV_TOOL_BIN_DIR" "$UV_CACHE_DIR" "$UV_PYTHON_INSTALL_DIR"; do
  test -w "$dir"
  case "$dir" in /opt/*) ;; *) exit 1 ;; esac
done
scratch=$(mktemp -d)
# This trap deletes only the unique fixture directory created immediately above.
trap 'rm -rf -- "$scratch"' EXIT
printf 'ordinary development text\n' > "$scratch/clean.txt"
betterleaks dir "$scratch" --no-banner --redact --exit-code 42 >/dev/null 2>&1
python3 - "$scratch" <<'PY'
import pathlib
import secrets
import sys
# Synthetic token; generated only in the disposable fixture, never a credential.
token = "ghp_" + secrets.token_hex(18)
pathlib.Path(sys.argv[1], "fixture.txt").write_text("github_token=" + token + "\n")
PY
result=0
betterleaks dir "$scratch" --no-banner --redact --exit-code 42 >/dev/null 2>&1 || result=$?
test "$result" -eq 42
if [[ "$profile" != base ]]; then
  python3 --version
  uv --version
  ruff --version
  uv venv --offline --python /usr/bin/python3 "$scratch/venv"
  "$scratch/venv/bin/python" -c 'assert sum([1, 2, 3]) == 6'
  printf 'value = 1\n' | ruff check --isolated --no-cache -
fi
if [[ "$profile" == infra ]]; then
  for tool in yamllint openssl ip ping dig ncat restic; do command -v "$tool" >/dev/null; done
  python3 -c 'import yaml; assert yaml.safe_load("enabled: true")["enabled"] is True'
  printf '%s\n' '---' 'enabled: true' | yamllint -
  restic version
fi
printf 'PASS: %s Toolbox tools, paths, offline smoke checks and synthetic secret detection\n' "$profile"
CHECKS
