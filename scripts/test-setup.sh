#!/usr/bin/env bash
# Isolated behavioral tests; no real Podman storage or Toolbox is accessed.
if ((BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3))); then
  printf 'ERROR: Bash 5.3+ required\n' >&2
  exit 69
fi
set -Eeuo pipefail
shopt -s inherit_errexit nullglob
trap 'printf "ERROR: setup test failed at line %s\n" "$LINENO" >&2' ERR
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export TEST_STATE="$scratch/state"
mkdir -p "$scratch/bin" "$TEST_STATE"
# Test fixtures intentionally implement only the external runtime interface.
cat > "$scratch/bin/podman" <<'MOCK'
#!/usr/bin/env bash
set -eu
key() { printf '%s' "$1" | tr '/:' '__'; }
case "$1 $2" in
  'image exists') test -f "$TEST_STATE/$(key "$3")" ;;
  'image inspect')
    if [[ "$4" == *parent-id* ]]; then cat "$TEST_STATE/$(key "$5").parent";
    else cat "$TEST_STATE/$(key "$5")"; fi ;;
  'container exists') test -f "$TEST_STATE/container-$3" ;;
  'container inspect') cat "$TEST_STATE/container-$5" ;;
  build*)
    [[ ${TEST_BUILD_FAIL:-0} == 0 ]] || exit 9
    image='' parent=''
    while (($#)); do
      case "$1" in
        --tag) image=$2; shift ;;
        --label) parent=${2#*=}; shift ;;
      esac
      shift
    done
    printf '%s\n' "$image" >> "$TEST_STATE/builds"
    printf 'id-%s\n' "$(key "$image")" > "$TEST_STATE/$(key "$image")"
    printf '%s\n' "$parent" > "$TEST_STATE/$(key "$image").parent" ;;
  *) exit 99 ;;
esac
MOCK
cat > "$scratch/bin/toolbox" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ "$1" == create && "$2" == --image && "$4" == --container ]]
key=$(printf '%s' "$3" | tr '/:' '__')
cat "$TEST_STATE/$key" > "$TEST_STATE/container-$5"
printf '%s\n' "$5" >> "$TEST_STATE/creates"
MOCK
chmod +x "$scratch/bin/podman" "$scratch/bin/toolbox"
export PATH="$scratch/bin:$PATH"
unset IMAGE_REF CONTAINER_NAME REBUILD REFRESH
bash "$root/setup.sh" infra
test "$(wc -l < "$TEST_STATE/builds")" -eq 3
test "$(head -1 "$TEST_STATE/builds")" = localhost/dev-base:fedora-44
test "$(tail -1 "$TEST_STATE/builds")" = localhost/dev-infra:fedora-44
bash "$root/setup.sh" infra
test "$(wc -l < "$TEST_STATE/builds")" -eq 3
test "$(wc -l < "$TEST_STATE/creates")" -eq 1
printf 'old-image\n' > "$TEST_STATE/container-dev-infra"
code=0
bash "$root/setup.sh" infra 2>/dev/null || code=$?
test "$code" -eq 70
test "$(cat "$TEST_STATE/container-dev-infra")" = old-image
code=0
bash "$root/setup.sh" invalid 2>/dev/null || code=$?
test "$code" -eq 64
code=0
TEST_BUILD_FAIL=1 REBUILD=1 bash "$root/setup.sh" base --build-only 2>/dev/null || code=$?
test "$code" -eq 9
CONTAINER_NAME=custom-base bash "$root/setup.sh" base --build-only
test ! -e "$TEST_STATE/container-custom-base"
printf 'new-parent\n' > "$TEST_STATE/localhost_dev-base_fedora-44"
bash "$root/setup.sh" python --build-only
test "$(wc -l < "$TEST_STATE/builds")" -eq 4
test "$(cat "$TEST_STATE/localhost_dev-python_fedora-44.parent")" = new-parent
IMAGE_REF=localhost/custom:44 CONTAINER_NAME=custom-python bash "$root/setup.sh" python
test -e "$TEST_STATE/container-custom-python"
code=0
IMAGE_REF=localhost/dev-base:fedora-44 bash "$root/setup.sh" python --build-only 2>/dev/null || code=$?
test "$code" -eq 64
before=$(wc -l < "$TEST_STATE/builds")
REFRESH=1 bash "$root/setup.sh" infra --build-only
test "$(wc -l < "$TEST_STATE/builds")" -eq "$((before + 3))"
printf 'PASS: profile ordering, repeat setup, stale containers, invalid input, build failure, build-only, parent changes and overrides\n'
