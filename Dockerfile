FROM python:3.12-slim@sha256:aa943ce411423c7582288f18707ff66eddcbaeb510502d747a72aeb34f30d159

ARG GIT_VERSION=1:2.47.3-0+deb13u1
ARG CA_CERTIFICATES_VERSION=20250419+deb13u1
ARG CURL_VERSION=8.14.1-2+deb13u7
ARG GH_VERSION=2.103.3
ARG CLAUDE_CODE_VERSION=2.1.316

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git=${GIT_VERSION} \
        ca-certificates=${CA_CERTIFICATES_VERSION} \
        curl=${CURL_VERSION} \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh=${GH_VERSION} \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.11.24 /uv /usr/local/bin/uv

# The Claude CLI refuses --dangerously-skip-permissions (the sidecar's bypassPermissions mode) when
# running as root, so derived images must run as this user.
RUN useradd --create-home app

WORKDIR /app
RUN chown app:app /app

# The CLI installs into the invoking user's home, so it is installed as that user.
USER app
WORKDIR /tmp
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION}

ENV PATH=/home/app/.local/bin:$PATH
# Blocks the CLI's background self-update, so the pinned version is the version that runs.
ENV DISABLE_UPDATES=1

WORKDIR /app
