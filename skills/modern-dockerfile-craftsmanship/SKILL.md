---
name: modern-dockerfile-craftsmanship
description: >-
  Use this skill when authoring, auditing, optimizing, or refactoring Dockerfiles:
  BuildKit syntax, multi-stage builds, non-root execution, distroless and minimal base images,
  layer caching, cache and secret mounts, PID 1 signal propagation, STOPSIGNAL, and container healthchecks.
---

# Modern Dockerfile Craftsmanship & Engineering

This skill provides comprehensive architectural patterns, security standards, and performance optimization guides for authoring production-grade Dockerfiles using the modern BuildKit engine.

---

## Core Engineering Principles

1. **BuildKit-First Architecture**:
   - Always declare `# syntax=docker/dockerfile:1` as the very first line of every Dockerfile to unlock modern BuildKit features across any Docker engine version.
   - Leverage BuildKit cache mounts (`--mount=type=cache`), secret mounts (`--mount=type=secret`), and bind mounts (`--mount=type=bind`).

2. **Strict Multi-Stage Separation**:
   - Decouple compilation, dependency resolution, and testing from the production runtime image.
   - Strip build tools, package managers, development dependencies, and compilers from shipping images to minimize image size and CVE attack surface.

3. **Deterministic, Minimal Base Images**:
   - Never use mutable tags such as `:latest` or unpinned distribution tracks.
   - Use immutable content hashes (SHA256 digests) or explicit semantic version tags.
   - Favor minimal, hardened base images: Google Distroless, Chainguard, Alpine Linux, or Debian Slim.

4. **Least-Privilege & Non-Root Execution**:
   - Applications must never execute as `root` (UID 0) inside production containers.
   - Explicitly create a non-root system user and group (e.g., `UID 10001:GID 10001`) or use built-in unprivileged users (e.g., `nonroot:nonroot` in Distroless).

5. **Layer Ordering & Cache Invalidation Discipline**:
   - Order Dockerfile instructions from least-frequently changing to most-frequently changing.
   - Copy dependency manifests (e.g., `package.json`, `pom.xml`, `go.mod`, `pyproject.toml`) and resolve dependencies before copying source code.

6. **POSIX Signal Propagation & PID 1 Management**:
   - Strictly mandate the exec form (`["executable", "param"]`) for `ENTRYPOINT` and `CMD`.
   - Never use shell form (`CMD executable param`), which runs as a subshell child process and absorbs `SIGTERM`/`SIGINT`, causing unclean shutdown and forced kills.
   - Set `STOPSIGNAL` when non-default signals are required (e.g., `STOPSIGNAL SIGQUIT` for Nginx).
   - Use an init system (`tini` or `dumb-init`) when runtime processes do not natively adopt and reap zombie processes.

---

## Directory Resources & References

- **Detailed Guides**:
  - [Multi-Stage Builds & Base Images](./references/multistage_builds_and_images.md)
  - [BuildKit Caching, Secrets & Multi-Platform](./references/buildkit_caching_and_secrets.md)
  - [Container Security, Non-Root & Process Runtime](./references/security_and_runtime.md)
- **Production Reference Implementations**:
  - [Node.js / TypeScript Dockerfile](./examples/node.Dockerfile)
  - [Go Statically-Linked Binary Dockerfile](./examples/go.Dockerfile)
  - [Python Fast uv Multi-Stage Dockerfile](./examples/python-uv.Dockerfile)
  - [Java 21 Spring Boot Layered Jars Dockerfile](./examples/java-spring-boot.Dockerfile)
- **Checklists & Tools**:
  - [Dockerfile Hardening & Audit Checklist](./resources/dockerfile-hardening-checklist.md)

---

## Production Golden Templates

### Example A: Hardened Multi-Stage Node.js / TypeScript Dockerfile
```dockerfile
# syntax=docker/dockerfile:1
ARG NODE_VERSION=22.12.0
ARG ALPINE_VERSION=3.20

# Stage 1: Dependency Resolution
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS deps
WORKDIR /usr/src/app

# Leverage BuildKit cache mount for npm cache to avoid redownloading
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --include=dev

# Stage 2: Compilation / Build
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS builder
WORKDIR /usr/src/app
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .
RUN npm run build \
    && npm prune --omit=dev

# Stage 3: Minimal Production Runtime
FROM gcr.io/distroless/nodejs22-debian12:nonroot AS runner
WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000

COPY --from=builder --chown=nonroot:nonroot /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /usr/src/app/dist ./dist
COPY --from=builder --chown=nonroot:nonroot /usr/src/app/package.json ./package.json

USER nonroot:nonroot
EXPOSE 3000

ENTRYPOINT ["/nodejs/bin/node", "dist/main.js"]
```

### Example B: Minimal Statically-Linked Go Binary (Distroless / Scratch)
```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder
WORKDIR /src

ARG TARGETOS TARGETARCH
RUN --mount=type=bind,source=go.mod,target=go.mod \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot AS runner
WORKDIR /app
COPY --from=builder --chown=nonroot:nonroot /out/app /app/server

USER nonroot:nonroot
EXPOSE 8080

ENTRYPOINT ["/app/server"]
```

### Example C: Java 21 Spring Boot 3 Layered Jars (Eclipse Temurin JRE)
```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /workspace

COPY gradlew gradlew.bat settings.gradle.kts build.gradle.kts ./
COPY gradle/ gradle/
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    ./gradlew dependencies --no-daemon

COPY src/ src/
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    ./gradlew bootJar --no-daemon -x test

# Extract layers using Spring Boot jarmode
RUN java -Djarmode=tools -jar build/libs/*.jar extract --layers --destination extracted/

FROM eclipse-temurin:21-jre-alpine AS runner
WORKDIR /app

RUN addgroup -g 10001 -S appgroup \
    && adduser -u 10001 -S appuser -G appgroup

# Copy individual layers in order of change frequency (least frequent to most frequent)
COPY --from=builder --chown=10001:10001 /workspace/extracted/dependencies/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/application/ ./

USER 10001:10001
EXPOSE 8080

ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

### Example D: High-Performance Python Microservice (uv)
```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim-bookworm AS builder
COPY --from=ghcr.io/astral-sh/uv:0.5.24 /uv /bin/uv
WORKDIR /app

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=cache,target=/root/.cache/uv \
    uv venv /app/.venv && uv sync --frozen --no-dev --no-install-project

COPY src/ /app/src/
RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

FROM python:3.12-slim-bookworm AS runner
WORKDIR /app

RUN groupadd -g 10001 appgroup \
    && useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser

COPY --from=builder --chown=10001:10001 /app/.venv /app/.venv
COPY --from=builder --chown=10001:10001 /app/src /app/src

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

USER 10001:10001
EXPOSE 8000

ENTRYPOINT ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
