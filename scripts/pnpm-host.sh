#!/usr/bin/env bash
# User-scoped pnpm lifecycle for Fedora 44 Kinoite (x86_64).
if ((BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3))); then
    printf 'ERROR: Bash 5.3+ is required.\n' >&2
    exit 69
fi
set -eEuo pipefail
shopt -s inherit_errexit nullglob

readonly PNPM_RELEASE=12.4.2
readonly SHA256=ce1ed690fe9c2f091d7267e1afbe9380abb08bb577e95348fda194a41147d2ec
readonly URL="https://github.com/pnpm/pnpm/releases/download/v$PNPM_RELEASE/pnpm-linux-x64.tar.gz"
die() { printf 'ERROR: %s\n' "$2" >&2; exit "$1"; }
usage() {
    cat <<'USAGE'
Usage: pnpm-host.sh install [--adopt] [--archive FILE]
       pnpm-host.sh uninstall
       pnpm-host.sh status

Installs pinned pnpm 12.4.2 in ~/.local/share/pnpm without sudo or Node.js.
--adopt explicitly takes over an existing pnpm home and known legacy setup.
--archive uses a previously downloaded official archive (checksum still required).
Uninstall archives the pnpm home, including its Node runtimes/global packages,
and removes managed shell/desktop integration. It never deletes project packages.
Backups remain in ~/.local/state/pnpm-kinoite. See docs/host-pnpm.md.
USAGE
}
action=${1:---help}
[[ $# == 0 ]] || shift
adopt=false
archive=''
while (($#)); do
    case $1 in
        --adopt) adopt=true ;;
        --archive) (($# >= 2)) || die 64 '--archive requires a file'; archive=$2; shift ;;
        *) die 64 "Unknown option: $1" ;;
    esac
    shift
done
case $action in
    --help|-h) usage; exit 0 ;;
    install|uninstall|status) ;;
    *) usage >&2; exit 64 ;;
esac
[[ $action == install || ( $adopt == false && -z $archive ) ]] || die 64 'Options apply only to install'
((EUID != 0)) || die 77 'Run as your normal user, without sudo'
[[ ! -e /run/.toolboxenv && ! -e /run/.containerenv && ! -e /.dockerenv ]] || die 77 'Run on the host, outside containers'
# shellcheck source=/dev/null
source /etc/os-release
[[ ${ID-} == fedora && ${VERSION_ID-} == 44 && ${VARIANT_ID-} == kinoite ]] || die 69 'Requires Fedora 44 Kinoite'
[[ $(uname -m) == x86_64 ]] || die 69 'Only x86_64 is supported'
for cmd in realpath stat awk cmp cp mv mkdir mktemp flock sha256sum tar install readlink; do
    command -v "$cmd" >/dev/null || die 69 "Missing command: $cmd"
done
user_home=$(realpath -e -- "$HOME")
readonly user_home
[[ $user_home != / && -d $user_home && $(stat -c %u "$user_home") == "$EUID" ]] || die 77 'HOME must be an existing directory owned by this user'
# Literal paths are embedded in Bash and environment.d; reject ambiguous syntax.
[[ $user_home =~ ^/[a-zA-Z0-9_./-]+$ ]] || die 64 'HOME must use letters, numbers, /, ., _, or -'
readonly pnpm_home="$user_home/.local/share/pnpm"
readonly state="$user_home/.local/state/pnpm-kinoite"
readonly helper="$user_home/.config/pnpm-kinoite/env.bash"
readonly desktop="$user_home/.config/environment.d/10-pnpm.conf"
readonly completion="$user_home/.local/share/bash-completion/completions/pnpm"
readonly begin='# >>> pnpm-kinoite >>>'
readonly end='# <<< pnpm-kinoite <<<'

# Never follow a symlink at or beneath our account root while modifying paths.
check_path() {
    local path=$1
    [[ $path == "$user_home/"* ]] || die 77 "Path escapes HOME: $path"
    while [[ $path != "$user_home" ]]; do
        [[ ! -L $path ]] || die 77 "Refusing symlink: $path"
        path=${path%/*}
    done
}
for path in "$pnpm_home" "$state" "$helper" "$desktop" "$completion" \
    "$user_home/.bashrc" "$user_home/.bash_profile" "$pnpm_home/bin" "$pnpm_home/.kinoite"; do
    check_path "$path"
done
if [[ ! -e $user_home/.bash_profile && ( -e $user_home/.bash_login || -e $user_home/.profile ) ]]; then
    die 73 'Existing .bash_login/.profile would be hidden by .bash_profile; integrate your custom login setup first'
fi
if [[ $action == status ]]; then
    if [[ -f $state/installed && -x $pnpm_home/bin/pnpm ]]; then
        printf 'Managed installation: %s\n' "$pnpm_home"
        "$pnpm_home/bin/pnpm" --version
    elif [[ -e $pnpm_home ]]; then
        printf 'Existing unmanaged installation: %s\nUse install --adopt to manage it.\n' "$pnpm_home"
    else
        printf 'pnpm is not installed at %s\n' "$pnpm_home"
    fi
    exit 0
fi
umask 077
mkdir -p "$state"
check_path "$state/lock"
exec 9>"$state/lock"
flock -n 9 || die 75 'Another pnpm-host operation is running'
if [[ $action == uninstall && ! -f $state/installed ]]; then
    [[ ! -e $pnpm_home ]] || die 73 'Unmanaged pnpm home; run install --adopt first'
    printf 'Already uninstalled.\n'
    exit 0
fi
if [[ $action == install && -e $pnpm_home && ! -f $state/installed && $adopt == false ]]; then
    die 73 'Existing pnpm home; use install --adopt to preserve and manage it'
fi

work=$(mktemp -d "$state/work.XXXXXXXX")
backup=''
committed=false
moved_home=false
home_existed=false
[[ ! -e $pnpm_home ]] || home_existed=true
declare -a targets=() keys=()
save() {
    local path=$1 key=$2
    check_path "$path"
    if [[ -e $path ]]; then
        cp -a -- "$path" "$backup/$key"
    fi
    targets+=("$path"); keys+=("$key")
}
finish() {
    local code=$? i
    trap - EXIT
    set +e
    if [[ $committed == false && -n $backup ]]; then
        printf 'Operation failed; restoring saved files from %s\n' "$backup" >&2
        if [[ $moved_home == true ]]; then
            mv -- "$backup/pnpm-home" "$pnpm_home" || code=74
        fi
        for ((i=${#targets[@]}-1; i>=0; i--)); do
            # Targets were individually checked and registered, never HOME itself.
            rm -rf -- "${targets[i]}" || code=74
            if [[ -e $backup/${keys[i]} ]]; then
                cp -a -- "$backup/${keys[i]}" "${targets[i]}" || code=74
            fi
        done
        if [[ $home_existed == false ]]; then
            rmdir -- "$pnpm_home/bin" "$pnpm_home" 2>/dev/null || true
        fi
    fi
    # work is a mktemp-created child of this script's state directory.
    [[ $work == "$state"/work.* ]] && rm -rf -- "$work"
    exit "$code"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Remove only our marked block or the two legacy pnpm blocks from this session.
# Any other PNPM_HOME declaration is a conflict to resolve explicitly.
printf '%s\nif [ -r "%s" ]; then\n    . "%s"\nfi\n%s\n' \
    "$begin" "$helper" "$helper" "$end" > "$work/shell.block"
cat > "$work/legacy.original" <<EOF
# pnpm
export PNPM_HOME='$pnpm_home'
case ":\$PATH:" in
  *":\$PNPM_HOME/bin:"*) ;;
  *) export PATH="\$PNPM_HOME/bin:\$PATH" ;;
esac
# pnpm end
EOF
cat > "$work/legacy.repaired" <<'EOF'
# pnpm: host installation; Toolbx uses its own tools.
if [[ -e /run/.toolboxenv ]]; then
    # Remove inherited host entries too: desktop sessions export this PATH.
    _pnpm_remove_host_path() {
        local remaining="${PATH-}" entry cleaned='' separator=''
        while :; do
            entry=${remaining%%:*}
            case "$entry" in
                "$HOME/.local/share/pnpm"|"$HOME/.local/share/pnpm/bin") ;;
                *) cleaned+="$separator$entry"; separator=':' ;;
            esac
            [[ $remaining == *:* ]] || break
            remaining=${remaining#*:}
        done
        export PATH="$cleaned"
    }
    _pnpm_remove_host_path
    unset -f _pnpm_remove_host_path
    if [[ ${PNPM_HOME-} == "$HOME/.local/share/pnpm" ]]; then
        unset PNPM_HOME
    fi
else
    export PNPM_HOME="$HOME/.local/share/pnpm"
    case ":$PATH:" in
        *":$PNPM_HOME/bin:"*) ;;
        *) export PATH="$PNPM_HOME/bin:$PATH" ;;
    esac
fi
# pnpm end
EOF
render_shell() {
    local input=$1 output=$2
    [[ -e $input ]] || input=/dev/null
    awk -v begin="$begin" -v end="$end" '
        $0 == begin || $0 == "# pnpm" || $0 == "# pnpm: host installation; Toolbx uses its own tools." { inside=1 }
        inside { print }
        $0 == end || $0 == "# pnpm end" { inside=0 }
    ' "$input" > "$work/found.block"
    if [[ -s $work/found.block ]]; then
        if ! cmp -s "$work/found.block" "$work/shell.block"; then
            [[ $adopt == true ]] || die 73 "Modified or unmanaged pnpm block in $input"
            cmp -s "$work/found.block" "$work/legacy.original" \
                || cmp -s "$work/found.block" "$work/legacy.repaired" \
                || die 73 "Unknown pnpm block in $input; preserve and migrate it manually"
        fi
    fi
    awk -v begin="$begin" -v end="$end" -v adopt="$adopt" '
        $0 == begin || $0 == "# pnpm" || $0 == "# pnpm: host installation; Toolbx uses its own tools." {
            if (inside || ++blocks > 1) exit 65
            if ($0 != begin && adopt != "true") exit 65
            inside=1; legacy=($0 != begin); next
        }
        $0 == end || $0 == "# pnpm end" {
            if (!inside || (legacy && $0 != "# pnpm end") || (!legacy && $0 != end)) exit 65
            inside=0; next
        }
        !inside { if ($0 ~ /PNPM_HOME/) exit 65; print }
        END { if (inside) exit 65 }
    ' "$input" > "$output" || die 65 "Ambiguous pnpm configuration in $input; no changes applied"
    if [[ $action == install ]]; then
        cat "$work/shell.block" >> "$output"
    fi
    bash -n "$output"
}
render_shell "$user_home/.bashrc" "$work/bashrc"
render_shell "$user_home/.bash_profile" "$work/bash_profile"

if [[ -f $state/installed ]]; then
    check_path "$state/files.sha256"
    [[ -f $state/files.sha256 ]] || die 73 'Missing ownership checksums; restore the state backup'
    sha256sum --check --status "$state/files.sha256" \
        || die 73 'Managed files were modified or removed; restore them before changing this installation'
fi

# Generated helper is deliberately Bash-only, invoked by both startup files.
cat > "$work/env.bash" <<EOF
# Managed by pnpm-host.sh
_pnpm_kinoite_env() {
    local host_pnpm='$pnpm_home' entry remaining="\${PATH-}" cleaned='' separator=''
    if [[ -e /run/.toolboxenv ]]; then
        while :; do
            entry=\${remaining%%:*}
            case "\$entry" in
                "\$host_pnpm"|"\$host_pnpm/bin") ;;
                *) cleaned+="\$separator\$entry"; separator=':' ;;
            esac
            [[ \$remaining == *:* ]] || break
            remaining=\${remaining#*:}
        done
        export PATH="\$cleaned"
        [[ \${PNPM_HOME-} != "\$host_pnpm" ]] || unset PNPM_HOME
    else
        export PNPM_HOME="\$host_pnpm"
        case ":\${PATH-}:" in
            *":\$host_pnpm/bin:"*) ;;
            *) export PATH="\$host_pnpm/bin:\${PATH-}" ;;
        esac
    fi
}
_pnpm_kinoite_env
unset -f _pnpm_kinoite_env
EOF
# environment.d expands these variables in the desktop session, not this shell.
# shellcheck disable=SC2016
printf '# Managed by pnpm-host.sh\nPNPM_HOME=%s\nPATH=${PNPM_HOME}/bin:${PATH}\n' "$pnpm_home" > "$work/desktop"
# shellcheck disable=SC2016
printf 'PNPM_HOME=%s\nPATH=${PNPM_HOME}/bin:${PATH}\n' "$pnpm_home" > "$work/desktop.legacy"
for pair in "$helper:env.bash" "$desktop:desktop"; do
    path=${pair%:*}; key=${pair##*:}
    if [[ -e $path ]] && ! cmp -s "$path" "$work/$key"; then
        if [[ $adopt != true || $key != desktop ]] || ! cmp -s "$path" "$work/desktop.legacy"; then
            die 73 "Refusing to replace modified or unowned configuration: $path"
        fi
    fi
done

# Only remove the exact host wrappers created by the earlier installation.
declare -a wrappers=()
for name in pnpm pnpx node npm npx; do
    path="$user_home/.local/bin/$name"
    check_path "$path"
    if [[ -e $path ]]; then
        [[ $adopt == true ]] || die 73 "Conflicting command: $path (use --adopt only for known pnpm wrappers)"
        printf '#!/bin/sh\nexec "%s/bin/%s" "$@"\n' "$pnpm_home" "$name" > "$work/wrapper"
        cmp -s "$path" "$work/wrapper" || die 73 "Unrelated command: $path"
        wrappers+=("$path")
    fi
done

if [[ $action == install ]]; then
    if [[ -n $archive ]]; then
        cp -- "$archive" "$work/pnpm.tar.gz"
    else
        command -v curl >/dev/null || die 69 'curl is required for download'
        curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
            --tlsv1.2 --connect-timeout 15 --max-time 300 --retry 2 "$URL" -o "$work/pnpm.tar.gz"
    fi
    printf '%s  %s\n' "$SHA256" "$work/pnpm.tar.gz" | sha256sum --check --status \
        || die 65 'Archive checksum mismatch; no installation changes applied'
    mkdir "$work/release"
    tar --extract --gzip --file "$work/pnpm.tar.gz" --directory "$work/release" --no-same-owner
    [[ -x $work/release/pnpm && -d $work/release/dist ]] || die 65 'Incomplete pnpm archive'
    [[ $("$work/release/pnpm" --version) == "$PNPM_RELEASE" ]] || die 65 'Unexpected pnpm version'
    "$work/release/pnpm" completion bash > "$work/completion"
    if [[ -e $completion && ! -f $state/installed ]]; then
        if [[ $adopt != true ]] || ! cmp -s "$completion" "$work/completion"; then
            die 73 "Unowned completion: $completion; preserve it before installation"
        fi
    fi
    printf '#!/bin/sh\nexec "%s/.kinoite/pnpm" "$@"\n' "$pnpm_home" > "$work/pnpm"
    printf '#!/bin/sh\nexec "%s/.kinoite/pnpm" dlx "$@"\n' "$pnpm_home" > "$work/pnpx"
fi

# Back up every file before changing it. PNPM_HOME itself is archived on uninstall.
backup=$(mktemp -d "$state/$action.XXXXXXXX")
for pair in "$user_home/.bashrc:bashrc" "$user_home/.bash_profile:bash_profile" \
    "$helper:env.bash" "$desktop:desktop" "$completion:completion" "$state/installed:installed" \
    "$state/files.sha256:files.sha256" "$state/created-shells:created-shells"; do
    save "${pair%:*}" "${pair##*:}"
done
for path in "${wrappers[@]}"; do save "$path" "wrapper-${path##*/}"; done
mkdir -p "${helper%/*}" "${desktop%/*}" "${completion%/*}"
if [[ $action == install ]]; then
    if [[ ! -f $state/installed ]]; then
        : > "$state/created-shells"
        for name in bashrc bash_profile; do
            [[ -e $user_home/.$name ]] || printf '%s\n' "$name" >> "$state/created-shells"
        done
    fi
    mkdir -p "$pnpm_home/bin"
    save "$pnpm_home/.kinoite" release
    save "$pnpm_home/bin/pnpm" pnpm
    save "$pnpm_home/bin/pnpx" pnpx
    rm -rf -- "$pnpm_home/.kinoite"
    mv -- "$work/release" "$pnpm_home/.kinoite"
    install -m 755 "$work/pnpm" "$pnpm_home/bin/pnpm"
    install -m 755 "$work/pnpx" "$pnpm_home/bin/pnpx"
    install -m 644 "$work/env.bash" "$helper"
    install -m 644 "$work/desktop" "$desktop"
    install -m 644 "$work/completion" "$completion"
    printf '%s\n' "$PNPM_RELEASE" > "$state/installed"
    sha256sum "$helper" "$desktop" "$completion" "$pnpm_home/bin/pnpm" "$pnpm_home/bin/pnpx" \
        > "$state/files.sha256"
else
    [[ -d $pnpm_home ]] || die 73 'Managed pnpm home is missing; restore it before uninstalling'
    mv -- "$pnpm_home" "$backup/pnpm-home"
    moved_home=true
    [[ ! -f $state/created-shells ]] || cp "$state/created-shells" "$work/created-shells"
    rm -f -- "$helper" "$desktop" "$completion" "$state/installed" "$state/files.sha256"
    rm -f -- "$state/created-shells"
fi
for name in bashrc bash_profile; do
    mode=644
    [[ ! -e $user_home/.$name ]] || mode=$(stat -c %a "$user_home/.$name")
    install -m "$mode" "$work/$name" "$user_home/.$name"
done
if [[ $action == uninstall && -f $work/created-shells ]]; then
    for name in bashrc bash_profile; do
        if grep -qx "$name" "$work/created-shells" && [[ ! -s $user_home/.$name ]]; then
            rm -- "$user_home/.$name"
        fi
    done
fi
for path in "${wrappers[@]}"; do rm -f -- "$path"; done
committed=true

# Update only our variables, preserving the user manager's other PATH entries.
# No user manager (e.g. offline setup) is supported; session refresh applies config.
if command -v systemctl >/dev/null && manager_env=$(systemctl --user show-environment 2>/dev/null); then
    manager_path=$(printf '%s\n' "$manager_env" | sed -n 's/^PATH=//p')
    if [[ -n $manager_path ]]; then
        cleaned='' separator='' remaining=$manager_path
        while :; do
            entry=${remaining%%:*}
            case $entry in
                "$pnpm_home"|"$pnpm_home/bin") ;;
                *) cleaned+="$separator$entry"; separator=':' ;;
            esac
            [[ $remaining == *:* ]] || break
            remaining=${remaining#*:}
        done
        if [[ $action == install ]]; then
            systemctl --user set-environment "PNPM_HOME=$pnpm_home" "PATH=$pnpm_home/bin:$cleaned" \
                || printf 'Session update unavailable; log out and back in.\n' >&2
        else
            systemctl --user set-environment "PATH=$cleaned" \
                || printf 'Session PATH update unavailable; log out and back in.\n' >&2
            if [[ $(printf '%s\n' "$manager_env" | sed -n 's/^PNPM_HOME=//p') == "$pnpm_home" ]]; then
                systemctl --user unset-environment PNPM_HOME \
                    || printf 'Session PNPM_HOME update unavailable; log out and back in.\n' >&2
            fi
        fi
    fi
fi
printf '%s complete. Recovery backup: %s\n' "$action" "$backup"
printf 'Open a new terminal; log out and back in for desktop-wide changes.\n'
if [[ $action == uninstall ]]; then
    printf 'pnpm-managed Node runtimes and globals were archived with pnpm; project files and external stores were preserved.\n'
fi
