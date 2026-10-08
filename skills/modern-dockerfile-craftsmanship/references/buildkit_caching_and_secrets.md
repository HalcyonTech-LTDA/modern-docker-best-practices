# BuildKit Caching, Secret Mounting & Multi-Platform Guide

Modern Docker builds rely on the BuildKit backend (`DOCKER_BUILDKIT=1`), which introduces advanced mount types, concurrent stage execution, graph-based caching, and secure secret handling.

---

## 1. Enabling BuildKit Syntax

Always specify the syntax directive at the beginning of the file:
```dockerfile
# syntax=docker/dockerfile:1
```
This tells Docker to fetch the latest stable BuildKit frontend parser image at build time, guaranteeing compatibility with new features regardless of the host daemon version.

---

## 2. High-Performance Package Cache Mounts (`--mount=type=cache`)

Cache mounts persist across build invocations without baking downloaded dependencies into final image layers. This drastically speeds up both local builds and CI/CD runs.

### Package Manager Recipes:

#### Debian / Ubuntu (`apt`):
```dockerfile
# Keep package lists cached across runs
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl
```

#### Alpine Linux (`apk`):
```dockerfile
RUN --mount=type=cache,target=/etc/apk/cache \
    apk add --update-cache \
        ca-certificates \
        tzdata
```

#### Node.js (`npm` & `pnpm`):
```dockerfile
# npm cache mount
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci

# pnpm store cache mount
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile
```

#### Python (`pip` & `uv`):
```dockerfile
# pip cache mount
RUN --mount=type=bind,source=requirements.txt,target=requirements.txt \
    --mount=type=cache,target=/root/.cache/pip \
    pip install --no-compile -r requirements.txt

# uv cache mount
RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev
```

#### Go Modules & Build Cache:
```dockerfile
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -v -o /out/app .
```

#### Java (Gradle & Maven):
```dockerfile
# Gradle cache mount
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    ./gradlew assemble --no-daemon

# Maven cache mount
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn clean package -DskipTests
```

---

## 3. Zero-Leak Build Secrets (`--mount=type=secret`)

### Anti-Pattern: `ARG` or `ENV` for Secrets
```dockerfile
# ❌ CRITICAL SECURITY FLAW: ARG values are stored permanently in the image history
ARG NPM_TOKEN
RUN echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc && npm install
```
Anyone running `docker history <image>` or inspecting image layers can easily extract the plaintext token.

### Best Practice: BuildKit Secret Mount
Secret mounts expose sensitive files via an in-memory `tmpfs` only during the execution of that specific `RUN` command. The secret is never written to disk, cached, or committed to any image layer.

```dockerfile
# ✅ Secure: token is available at /run/secrets/npm_token during this command only
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) \
    npm ci
```

#### Invoking the Build with Secret:
```bash
# Pass secret from file or environment variable:
docker build --secret id=npm_token,src=.npm_token .
# OR pass from current shell environment:
docker build --secret id=npm_token,env=NPM_TOKEN .
```

#### Private Git Repositories via SSH:
```dockerfile
# Mount SSH agent socket during clone/fetch
RUN --mount=type=ssh git clone git@github.com:myorg/private-repo.git
```
```bash
docker build --ssh default .
```

---

## 4. Bind Mounts (`--mount=type=bind`)

Bind mounts permit accessing files from the host context directly in a `RUN` instruction without using a preceding `COPY` instruction.

```dockerfile
# Copies nothing into the layer; accesses package files directly for installation
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci --omit=dev
```
**Advantage**: Eliminates extra `COPY` steps that needlessly populate intermediate layer caches when the files are only needed for a single build step.

---

## 5. High-Speed Multi-Platform Builds

When building for multiple CPU architectures (`linux/amd64`, `linux/arm64`), standard QEMU emulation is notoriously slow. Use BuildKit's built-in platform arguments for fast cross-compilation:

```dockerfile
# syntax=docker/dockerfile:1
# Run compiler on BUILDPLATFORM (native CPU host), emit binary for TARGETPLATFORM
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -o /app/server .

# Target runner stage matches TARGETPLATFORM
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app/server /app/server
ENTRYPOINT ["/app/server"]
```

### Multi-Architecture Build Command:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t myorg/app:1.0.0 --push .
```
Because the Go compiler runs natively on the builder's architecture instead of under QEMU emulation, build times drop by 80–90%.

---

## 6. Safe Build-Time Metadata & Git Provenance (Without Leaking `.git`)

### Anti-Pattern: Un-ignoring `.git` to Run `git rev-parse`
```dockerfile
# ❌ DANGEROUS: Copies entire Git history, credentials, and invalidates layer caches
COPY .git .git
RUN git rev-parse HEAD > /app/version
```

### Best Practice: Injecting via Build Arguments & OCI Labels
Inject commit hashes and versions as build arguments from your host or CI environment:
```dockerfile
# syntax=docker/dockerfile:1
FROM alpine:3.20 AS runner
ARG COMMIT_SHA=unknown
ARG BUILD_TIME=unknown

LABEL org.opencontainers.image.revision=$COMMIT_SHA \
      org.opencontainers.image.created=$BUILD_TIME

ENV APP_VERSION=$COMMIT_SHA
```

Build command:
```bash
docker build \
  --build-arg COMMIT_SHA=$(git rev-parse --short HEAD) \
  --build-arg BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  -t my-app:latest .
```

BuildKit also generates standardized OCI provenance attestations and SBOMs directly:
```bash
docker buildx build --provenance=mode=max --sbom=true -t my-app:latest .
```
