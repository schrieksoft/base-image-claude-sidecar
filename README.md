# base-image-claude-sidecar

Static base image for the Snap CD Agent's Claude sidecar. It bakes the OS-level prerequisites and the Claude Code CLI onto `python:3.12-slim`, so the application Dockerfile in `snapcd/SnapCd.Agent/Sidecars/Claude/` can be a thin `FROM <base> + uv sync + COPY app + CMD`.

| Dockerfile   | Adds                                                                                   | Published as                                              |
|--------------|----------------------------------------------------------------------------------------|-----------------------------------------------------------|
| `Dockerfile` | `nodejs` (Node 22 from NodeSource, with npm), `git`, `curl`, `ca-certificates`, `gnupg`, `gh`, `uv`, `@anthropic-ai/claude-code`, the non-root `app` user | `ghcr.io/schrieksoft/base-image-claude-sidecar:<SemVer>` |

## Pinning

Everything is pinned, and every pin is an ARG at the top of the Dockerfile:

| ARG | Pins |
|---|---|
| `CLAUDE_CODE_VERSION` | the npm version of `@anthropic-ai/claude-code` |
| `GIT_VERSION`, `CA_CERTIFICATES_VERSION`, `CURL_VERSION`, `GNUPG_VERSION` | Debian package versions from the `python:3.12-slim` apt sources |
| `GH_VERSION` | the GitHub CLI version from `cli.github.com/packages` |
| `NODEJS_VERSION` | Node from `deb.nodesource.com/node_22.x`; this package bundles npm, so there is no separate npm pin |

The `FROM` line pins `python:3.12-slim` by digest as well as tag, so a rebuild of the same commit produces the same image.

`git` and `gh` are runtime dependencies, not build tools: Claude Code shells out to both.

Node comes from NodeSource rather than Debian because Claude Code declares `node >=22.0.0` and Debian trixie ships Node 20. Installing the Debian package makes npm emit `EBADENGINE` at build time and leaves the CLI running on a Node version upstream does not support.

### Updating the Claude Code CLI

This is the common case and does not require a Snap CD release:

1. `npm view @anthropic-ai/claude-code version` to get the target.
2. Bump `CLAUDE_CODE_VERSION` here, commit, push to `main`.
3. Bump the `FROM` tag in `snapcd/SnapCd.Agent/Sidecars/Claude/Dockerfile` to the new SemVer.

### Updating the Debian pins

Debian point releases retire old package versions from the archive, so a stale pin eventually fails the build with `Version '<x>' for '<pkg>' was not found`. When that happens, resolve the current candidates and bump them together:

```bash
docker run --rm python:3.12-slim bash -c '
apt-get update -qq >/dev/null 2>&1
apt-get install -y --no-install-recommends curl ca-certificates gnupg >/dev/null 2>&1
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt-get update -qq >/dev/null 2>&1
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod go+r /etc/apt/keyrings/nodesource.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
apt-get update -qq >/dev/null 2>&1
for p in nodejs git ca-certificates curl gnupg gh; do
  echo "$p=$(apt-cache policy $p | sed -n "s/^  Candidate: //p")"
done'
```

Bumping the `python:3.12-slim` digest usually means bumping all the Debian pins in the same commit.

## Building locally

From this directory:

```bash
docker build -f Dockerfile -t base-image-claude-sidecar:local .
```

Verify the tools are present:

```bash
docker run --rm base-image-claude-sidecar:local \
    sh -c "node --version && npm --version && git --version && gh --version | head -1 && uv --version && claude --version"
```

### Trying it as the sidecar's base

Point the sidecar's Dockerfile at the local tag temporarily:

```bash
# In applications/snapcd/SnapCd.Agent/Sidecars/Claude/Dockerfile, swap the FROM line:
#   FROM ghcr.io/schrieksoft/base-image-claude-sidecar:<ver>
# →
#   FROM base-image-claude-sidecar:local
```

Then build the sidecar image as you normally would. Revert before committing.

### Multi-arch

The published workflow is amd64-only, matching the rest of the Snap CD container family. To build locally for arm64, use buildx:

```bash
docker buildx build --platform linux/arm64 -f Dockerfile -t base-image-claude-sidecar:local-arm64 .
```

## What stays in the sidecar image

Python dependencies (`pyproject.toml` and `uv sync`) are deliberately *not* baked in here. They change on the application's schedule, and keeping them downstream means adding a package is a one-line edit in one repo rather than a base image release followed by a tag bump.

## Release flow

1. Push to `main` → `release.yaml` runs → the image is published to GHCR under the SemVer GitVersion computes from commit history.
2. The first published version creates a *private* GHCR package — flip it to *public* in `Settings → Packages → base-image-claude-sidecar` so downstream `FROM` lines can pull without auth.
3. To consume, bump the pinned tag in the sidecar's `FROM` line. Bumps are manual; no automated dispatch is wired up.

To force a specific version bump, follow the Snap CD family GitVersion conventions in your commit message:

- `+semver: major` / `+semver: breaking`
- `+semver: minor` / `+semver: feature`
- `+semver: patch` / `+semver: fix`
- `+semver: skip` to leave the version untouched
