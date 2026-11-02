FROM python:3.12-slim@sha256:aa943ce411423c7582288f18707ff66eddcbaeb510502d747a72aeb34f30d159

ARG NODEJS_VERSION=22.23.4-1nodesource1
ARG GIT_VERSION=1:2.47.3-0+deb13u1
ARG CA_CERTIFICATES_VERSION=20250419+deb13u1
ARG CURL_VERSION=8.14.1-2+deb13u7
ARG GNUPG_VERSION=2.4.7-21+deb13u1
ARG GH_VERSION=2.103.3
ARG CLAUDE_CODE_VERSION=2.1.316

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git=${GIT_VERSION} \
        ca-certificates=${CA_CERTIFICATES_VERSION} \
        curl=${CURL_VERSION} \
        gnupg=${GNUPG_VERSION} \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && chmod go+r /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        gh=${GH_VERSION} \
        nodejs=${NODEJS_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Claude Code shells out to git and gh, so both are runtime dependencies rather than build tools.
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

COPY --from=ghcr.io/astral-sh/uv:0.11.24 /uv /usr/local/bin/uv

# The Claude CLI refuses --dangerously-skip-permissions (the sidecar's bypassPermissions mode) when
# running as root, so derived images must run as this user.
RUN useradd --create-home app

WORKDIR /app
RUN chown app:app /app
