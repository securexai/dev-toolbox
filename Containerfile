# syntax=docker/dockerfile:1
# dev-toolbox: pinned Fedora toolbox image whose tooling is fully container-local.
# When `toolbox rm dev` runs, every tool installed below disappears with the
# container. Nothing lands in $HOME (which the toolbox bind-mounts from the host),
# so the immutable Fedora rpm-ostree deployment stays untouched and the
# user's host filesystem keeps no toolbox residue.
#
# Forked from scripts/.toolbox/Containerfile with three host-leak fixes:
#   1. ENV UV_TOOL_DIR + UV_TOOL_BIN_DIR so post-build `uv tool install` lands
#      in /opt/uv-tools, not ~/.local/share/uv (set in the `ENV UV_TOOL_DIR`
#      directive below).
#   2. ENV PRE_COMMIT_HOME so pre-commit hook environments cache in
#      /opt/pre-commit-cache, not ~/.cache/pre-commit (set in the
#      `ENV PRE_COMMIT_HOME` directive below).
#   3. /srv/work as the workspace root for cloned repos — outside the
#      bind-mounted $HOME, so the repo dies with `toolbox rm`. Created by
#      the final `RUN mkdir -p /srv/work` block near the end of this file.
#
# Tag-pinned to fedora-toolbox:43. Image integrity rides on the Fedora
# registry's HTTPS chain and the dnf GPG verification inside the build.
# For stricter reproducibility, replace ":43" with "@sha256:<digest>" and
# record the digest's source date here.

FROM registry.fedoraproject.org/fedora-toolbox:43

LABEL com.github.containers.toolbox="true"
LABEL org.opencontainers.image.title="dev-toolbox"
LABEL org.opencontainers.image.description="Pinned dev toolbox (tools + workspace are container-local; deleting the container deletes everything)."
LABEL org.opencontainers.image.source="https://github.com/conpwxp/dev-toolbox"
LABEL org.opencontainers.image.licenses="MIT"

# System tools via dnf. install_weak_deps=False drops nodejs's recommends
# (nodejs-npm, nodejs-docs, nodejs-full-i18n — ~140 MB we don't need).
# shellcheck and shfmt come from Fedora repos, so the GPG-signed package chain
# is the integrity gate (no manual sha256 wrangling).
RUN dnf install -y --setopt=install_weak_deps=False \
      git \
      gh \
      pre-commit \
      nodejs \
      python3 \
      curl \
      ca-certificates \
      jq \
      ripgrep \
      libatomic \
      shellcheck \
      shfmt \
 && dnf clean all \
 && rm -rf /var/cache/dnf

# Leak fix 1: post-build `uv tool install` defaults to ~/.local/share/uv (in
# $HOME, bind-mounted from host). Pin both dirs to /opt so any later install
# inside an interactive shell stays container-local.
ENV UV_TOOL_DIR=/opt/uv-tools
ENV UV_TOOL_BIN_DIR=/usr/local/bin

# Leak fix 2: pre-commit caches hook environments to $PRE_COMMIT_HOME, which
# defaults to ~/.cache/pre-commit. Redirect to /opt and make the directory
# world-writable so the host UID (which toolbox enters with) can write there.
ENV PRE_COMMIT_HOME=/opt/pre-commit-cache
# Mode 1777 (world-writable + sticky) is intentional: toolbox enters with
# the host user's UID, which is not known at image build time. These cache
# dirs must be writable by whoever enters the container. Sticky bit keeps
# the cleanup story sane on shared hosts. In a single-user toolbox the
# practical exposure is the same as $HOME being writable by you.
RUN mkdir -p /opt/pre-commit-cache /opt/uv-tools \
 && chmod 1777 /opt/pre-commit-cache /opt/uv-tools

# uv: system-wide binary in /usr/local/bin. INSTALLER_NO_MODIFY_PATH prevents
# the installer from rewriting any shell rc files on the host's $HOME at runtime.
ARG UV_VERSION=0.11.8
RUN curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" \
      | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh \
 && /usr/local/bin/uv --version

# ruff: image-scope install via uv. The UV_TOOL_DIR ENV above ensures every
# subsequent `uv tool install` (here and at runtime) lands in /opt/uv-tools,
# never in $HOME.
RUN uv tool install ruff \
 && ruff --version

# betterleaks: distributed as a Go release tarball on GitHub. Version + sha256
# pinned; build fails fast on mismatch. amd64-only — add an arm64 branch if
# the toolbox ever needs to run on Apple Silicon / arm64 Linux.
ARG BETTERLEAKS_VERSION=1.1.2
ARG BETTERLEAKS_SHA256=648c20617178065072ff1791d383192a62c911d9b4427f0426a8c504a6d9ddad
RUN set -eu; \
    url="https://github.com/betterleaks/betterleaks/releases/download/v${BETTERLEAKS_VERSION}/betterleaks_${BETTERLEAKS_VERSION}_linux_x64.tar.gz"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL -o "${tmp}/betterleaks.tar.gz" "${url}"; \
    printf '%s  %s\n' "${BETTERLEAKS_SHA256}" "${tmp}/betterleaks.tar.gz" \
      | sha256sum -c -; \
    tar -xzf "${tmp}/betterleaks.tar.gz" -C "${tmp}"; \
    bin="$(find "${tmp}" -type f -name betterleaks -print -quit)"; \
    [ -n "${bin}" ] || { echo "betterleaks binary not found in archive"; exit 1; }; \
    install -m 0755 "${bin}" /usr/local/bin/betterleaks; \
    rm -rf "${tmp}"; \
    /usr/local/bin/betterleaks version 2>/dev/null \
      || /usr/local/bin/betterleaks --version

# pnpm: pinned binary from upstream GitHub release. pnpm 11+ ships
# pnpm-linux-x64.tar.gz with a `pnpm` launcher (embedded Node, ~124 MB ELF)
# next to `dist/`. Extract to /opt/pnpm and symlink the launcher onto PATH.
# Fedora's nodejs package strips out corepack, so `corepack enable` isn't an
# option. Global installs go straight to /usr/local/bin via --global-bin-dir.
# --global-dir holds the package store under /opt so $HOME stays untouched.
ARG PNPM_VERSION=11.0.3
ARG PNPM_SHA256=5c236f22568453e76f05c2c0a37b483d326ddb3c7759f3b7a7f13a8860109771
RUN set -eu; \
    url="https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}/pnpm-linux-x64.tar.gz"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL -o "${tmp}/pnpm.tar.gz" "${url}"; \
    printf '%s  %s\n' "${PNPM_SHA256}" "${tmp}/pnpm.tar.gz" \
      | sha256sum -c -; \
    mkdir -p /opt/pnpm; \
    tar -xzf "${tmp}/pnpm.tar.gz" -C /opt/pnpm; \
    ln -s /opt/pnpm/pnpm /usr/local/bin/pnpm; \
    rm -rf "${tmp}"; \
    mkdir -p /opt/pnpm-global; \
    pnpm --version; \
    # These pnpm globals are for ad-hoc CLI use inside the toolbox
    # (e.g. `commitlint --help`, one-off `markdownlint-cli2 README.md`).
    # The actual pre-commit gate versions are pinned in
    # templates/.pre-commit-config.yaml: commitlint pins
    # `@commitlint/cli` and `@commitlint/config-conventional` via
    # `additional_dependencies`; markdownlint-cli2 is version-pinned via
    # the hook repo's `rev:` tag. Image binary != gate binary by design —
    # refresh either side independently.
    pnpm add -g \
      --global-dir=/opt/pnpm-global \
      --global-bin-dir=/usr/local/bin \
      @commitlint/cli @commitlint/config-conventional markdownlint-cli2; \
    commitlint --version; \
    markdownlint-cli2 --help >/dev/null

# Workspace: /srv/work is the canonical location for cloned repos inside the
# toolbox. Toolbox does NOT bind-mount /srv (only $HOME, /tmp, /run/user/$UID,
# and a small whitelist), so anything under /srv/work is container-overlay
# storage and disappears with `toolbox rm`. Mode 1777 (sticky-bit, world-write)
# lets the host UID write here regardless of what UID toolbox runs as.
RUN mkdir -p /srv/work \
 && chmod 1777 /srv/work

# Toolbox enters with the host user's UID; no USER directive needed.
CMD ["/bin/bash"]
