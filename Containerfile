# syntax=docker/dockerfile:1
ARG FEDORA_RELEASE=44
FROM registry.fedoraproject.org/fedora-toolbox:${FEDORA_RELEASE}

LABEL com.github.containers.toolbox="true"
LABEL org.opencontainers.image.title="dev-base"
LABEL org.opencontainers.image.description="Shared Fedora development utilities and repository checks"
LABEL org.opencontainers.image.source="https://github.com/conpwxp/dev-toolbox"
LABEL org.opencontainers.image.licenses="MIT"

# Fedora RPMs follow signed repository updates. Record resolved versions below.
# Python is pulled in by pre-commit. libatomic supports hook-managed Node binaries.
RUN dnf install -y --setopt=install_weak_deps=False \
      bash bash-completion ca-certificates coreutils curl diffutils file \
      findutils git gh gzip jq less libatomic make openssh-clients procps-ng \
      ripgrep rsync tar unzip util-linux which zip pre-commit ShellCheck shfmt \
 && dnf clean all

# Toolbx shares HOME. Redirect managed caches/tools into container storage.
# Sticky directories accommodate the host UID, which is unknown during build.
ENV PRE_COMMIT_HOME=/opt/pre-commit-cache
ENV UV_TOOL_DIR=/opt/uv-tools
ENV UV_TOOL_BIN_DIR=/opt/uv-bin
ENV UV_CACHE_DIR=/opt/uv-cache
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
ENV PATH="/opt/uv-bin:${PATH}"
RUN mkdir -p /opt/pre-commit-cache /opt/uv-tools /opt/uv-bin \
      /opt/uv-cache /opt/uv-python \
 && chmod 1777 /opt/pre-commit-cache /opt/uv-tools /opt/uv-bin \
      /opt/uv-cache /opt/uv-python

# Existing x86_64-only release; fail explicitly on unsupported architectures.
RUN test "$(uname -m)" = x86_64
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


RUN mkdir -p /usr/share/dev-toolbox \
 && rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
      | sort > /usr/share/dev-toolbox/rpm-manifest.txt

CMD ["/bin/bash"]
