#!/usr/bin/env bash
# Tests use a temporary home mounted over the account home; no real install.
# Child-shell commands and environment.d fixtures deliberately retain variables.
# shellcheck disable=SC2016
if ((BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3))); then
    printf 'Bash 5.3+ required\n' >&2
    exit 69
fi
set -eEuo pipefail
shopt -s inherit_errexit nullglob
[[ $# == 1 && -f $1 ]] || { printf 'Usage: %s OFFICIAL_PNPM_ARCHIVE\n' "$0" >&2; exit 64; }
archive=$(realpath "$1")
script=$(realpath "$(dirname "${BASH_SOURCE[0]}")/pnpm-host.sh")
root=$(mktemp -d /tmp/test-pnpm-host.XXXXXXXX)
trap 'printf "Test fixtures retained: %s\n" "$root"' EXIT
cp "$script" "$root/pnpm-host.sh"
script="$root/pnpm-host.sh"
mkdir -p "$root/home" "$root/bin"
cat > "$root/bin/systemctl" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$HOME/systemctl.log"
case "$*" in
    '--user show-environment')
        printf 'PATH=/usr/local/bin:%s/.local/share/pnpm/bin:/usr/bin:/bin\nPNPM_HOME=%s/.local/share/pnpm\n' "$HOME" "$HOME" ;;
esac
MOCK
cat > "$root/bin/curl" <<'MOCK'
#!/bin/sh
echo 'Simulated network failure' >&2
exit 22
MOCK
chmod +x "$root/bin/systemctl" "$root/bin/curl"
cat > "$root/bin/install" <<'MOCK'
#!/bin/bash
target=${!#}
if [[ -f $HOME/fail-install && $target == "$HOME/.config/environment.d/10-pnpm.conf" ]] ||
   [[ -f $HOME/fail-shell-write && $target == "$HOME/.bashrc" ]]; then
    echo 'Simulated write failure' >&2
    exit 74
fi
exec /usr/bin/install "$@"
MOCK
chmod +x "$root/bin/install"
base=(bwrap --unshare-user --unshare-pid --die-with-parent --ro-bind / / --dev /dev --proc /proc --tmpfs /run
    --bind "$root/home" "$HOME" --ro-bind "$root/bin" /usr/local/bin
    --setenv PATH /usr/local/bin:/usr/bin:/bin --unsetenv PNPM_HOME)
run() { "${base[@]}" /bin/bash "$script" "$@"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_failure() {
    local expected=$1
    shift
    local actual=0
    "$@" > "$root/last-error" 2>&1 || actual=$?
    [[ $actual == "$expected" ]] || { cat "$root/last-error" >&2; fail "Expected exit $expected, got $actual"; }
}
pnpm_home="$root/home/.local/share/pnpm"
state="$root/home/.local/state/pnpm-kinoite"
printf '# Existing user preferences\nexport KEEP_ME=yes\n' > "$root/home/.bashrc"
cp "$root/home/.bashrc" "$root/expected-bashrc"
printf '# Existing login preferences\n' > "$root/home/.bash_profile"
cp "$root/home/.bash_profile" "$root/expected-profile"

expect_failure 64 run install --unknown
expect_failure 22 run install
[[ ! -e $pnpm_home ]] || fail 'Network failure created installation'
printf broken > "$root/bad.tar.gz"
expect_failure 65 run install --archive "$root/bad.tar.gz"
cmp "$root/home/.bashrc" "$root/expected-bashrc"
printf 'PASS network/checksum failures preserve installation and shell configuration\n'

run install --archive "$archive"
run status
"${base[@]}" /bin/bash --login -c 'set -e; test "$(pnpm --version)" = 12.4.2; test "$(command -v pnpm)" = "$HOME/.local/share/pnpm/bin/pnpm"'
"${base[@]}" /bin/bash --noprofile -ic 'test "$(pnpm --version)" = 12.4.2'
[[ -s $root/home/.config/environment.d/10-pnpm.conf ]] || fail 'Missing desktop environment'
grep -F -- '--user set-environment PNPM_HOME=' "$root/home/systemctl.log" >/dev/null
cp "$root/home/.bashrc" "$root/first-bashrc"
run install --archive "$archive"
cmp "$root/home/.bashrc" "$root/first-bashrc"
printf 'PASS real pnpm install, Bash login/interactive, desktop update and repeated install\n'

touch "$root/home/fail-install"
expect_failure 74 run install --archive "$archive"
rm "$root/home/fail-install"
cmp "$root/home/.bashrc" "$root/first-bashrc"
"${base[@]}" /bin/bash --login -c 'test "$(pnpm --version)" = 12.4.2'
touch "$root/home/fail-shell-write"
expect_failure 74 run uninstall
rm "$root/home/fail-shell-write"
[[ -x $pnpm_home/bin/pnpm && -f $state/installed ]] || fail 'Failed uninstall did not restore installation'
cmp "$root/home/.bashrc" "$root/first-bashrc"
printf 'PASS install and uninstall rollback after injected write failures\n'

# Real Toolbx marker, fixture container command, hostile inherited PATH.
touch "$root/marker"
cat > "$root/bin/pnpm" <<'MOCK'
#!/bin/sh
echo container-pnpm
MOCK
chmod +x "$root/bin/pnpm"
"${base[@]}" --ro-bind "$root/marker" /run/.toolboxenv \
    --setenv PNPM_HOME "$HOME/.local/share/pnpm" \
    --setenv PATH "$HOME/.local/share/pnpm/bin:/usr/local/bin:/usr/bin:/bin" \
    /bin/bash --login -c 'set -e; test "$(pnpm)" = container-pnpm; test -z "${PNPM_HOME+x}"; before=$PATH; source ~/.bashrc; test "$PATH" = "$before"'
"${base[@]}" --ro-bind "$root/marker" /run/.toolboxenv \
    --setenv PNPM_HOME /opt/container-pnpm \
    /bin/bash --noprofile -ic 'set -e; test "$PNPM_HOME" = /opt/container-pnpm; test "$(pnpm)" = container-pnpm'
expect_failure 77 "${base[@]}" --ro-bind "$root/marker" /run/.toolboxenv /bin/bash "$script" install
printf 'PASS Toolbx isolation and container execution guard\n'

# Uninstall keeps global packages/runtimes in a recovery archive.
mkdir -p "$pnpm_home/global"
printf preserve > "$pnpm_home/global/sentinel"
printf user-node > "$pnpm_home/bin/node"
printf '# Later user preference\n' >> "$root/home/.bashrc"
printf '# Later user preference\n' >> "$root/expected-bashrc"
cp "$root/home/.config/pnpm-kinoite/env.bash" "$root/helper.original"
printf '# modified\n' >> "$root/home/.config/pnpm-kinoite/env.bash"
expect_failure 73 run uninstall
[[ -x $pnpm_home/bin/pnpm ]] || fail 'Conflict removed pnpm'
cp "$root/helper.original" "$root/home/.config/pnpm-kinoite/env.bash"
run uninstall
run uninstall
cmp "$root/home/.bashrc" "$root/expected-bashrc"
cmp "$root/home/.bash_profile" "$root/expected-profile"
[[ ! -e $pnpm_home && ! -e $root/home/.config/environment.d/10-pnpm.conf ]] || fail 'Uninstall left active installation'
backups=("$state"/uninstall.*/pnpm-home)
[[ ${#backups[@]} == 1 && -f ${backups[0]}/global/sentinel && -f ${backups[0]}/bin/node ]] || fail 'Uninstall lost global/runtime data'
grep -F -- '--user unset-environment PNPM_HOME' "$root/home/systemctl.log" >/dev/null
printf 'PASS conflict refusal, recoverable uninstall, repeated uninstall and user-file preservation\n'

# Legacy migration requires opt-in and preserves existing runtime/global files.
mkdir -p "$pnpm_home/bin" "$pnpm_home/global" "$root/home/.local/bin" "$root/home/.config/environment.d"
printf keep > "$pnpm_home/global/legacy"
printf keep-node > "$pnpm_home/bin/node"
cat >> "$root/home/.bashrc" <<EOF
# pnpm
export PNPM_HOME='$HOME/.local/share/pnpm'
case ":\$PATH:" in
  *":\$PNPM_HOME/bin:"*) ;;
  *) export PATH="\$PNPM_HOME/bin:\$PATH" ;;
esac
# pnpm end
EOF
printf 'PNPM_HOME=%s/.local/share/pnpm\nPATH=${PNPM_HOME}/bin:${PATH}\n' "$HOME" > "$root/home/.config/environment.d/10-pnpm.conf"
printf '#!/bin/sh\nexec "%s/.local/share/pnpm/bin/node" "$@"\n' "$HOME" > "$root/home/.local/bin/node"
expect_failure 73 run install --archive "$archive"
run install --adopt --archive "$archive"
[[ -f $pnpm_home/global/legacy && -f $pnpm_home/bin/node && ! -e $root/home/.local/bin/node ]] || fail 'Adoption lost data or left a wrapper'
run uninstall
printf 'PASS explicit adoption and legacy cleanup\n'

ln -s /tmp "$pnpm_home"
expect_failure 77 run install --archive "$archive"
rm "$pnpm_home"
printf 'ID=fedora\nVERSION_ID=43\nVARIANT_ID=kinoite\n' > "$root/os-release"
expect_failure 69 "${base[@]}" --ro-bind "$root/os-release" "$(realpath /etc/os-release)" /bin/bash "$script" install
expect_failure 77 "${base[@]}" --uid 0 --gid 0 /bin/bash "$script" install
printf 'PASS symlink, unsupported OS and root guards\n'

# Unknown legacy block bodies must never be silently stripped.
printf '# pnpm\nexport IMPORTANT_USER_SETTING=keep\n# pnpm end\n' >> "$root/home/.bashrc"
cp "$root/home/.bashrc" "$root/custom-bashrc"
expect_failure 73 run install --adopt --archive "$archive"
cmp "$root/home/.bashrc" "$root/custom-bashrc"
cp "$root/expected-bashrc" "$root/home/.bashrc"
rm "$root/home/.bash_profile"
printf 'export CUSTOM_LOGIN=keep\n' > "$root/home/.profile"
expect_failure 73 run install --archive "$archive"
[[ ! -e $root/home/.bash_profile ]] || fail 'Alternative login file was masked'
rm "$root/home/.profile"
run install --archive "$archive"
run uninstall
[[ ! -e $root/home/.bash_profile ]] || fail 'Script-created empty login file was not removed'
printf 'PASS legacy block ownership and login-file preservation\n'
printf 'PASS all lifecycle tests\n'
