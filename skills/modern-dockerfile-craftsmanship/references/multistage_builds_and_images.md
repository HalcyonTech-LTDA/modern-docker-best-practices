# Multi-Stage Builds & Base Image Selection Guide

Multi-stage builds are the cornerstone of modern container architecture. They decouple the environment required to compile and test code from the environment required to run code in production, eliminating build tools, compilers, development libraries, and package managers from shipping artifacts.

---

## 1. Multi-Stage Architectural Pattern

A production-grade multi-stage Dockerfile typically organizes into 4 to 5 discrete stages:

```text
┌─────────────────┐
│   base/deps     │  Resolves package manifests and downloads dependencies
└────────┬────────┘
         ▼
┌─────────────────┐
│     builder     │  Compiles source code into production binary / bundle
└────────┬────────┘
         ├───► ┌─────────────┐
         │     │    test     │ Optional target for CI (`--target test`)
         │     └─────────────┘
         ▼
┌─────────────────┐
│     runner      │  Ultra-minimal runtime image (Distroless / Scratch / Alpine)
└─────────────────┘
```

### Key Advantages:
1. **Dramatic Attack Surface Reduction**: Eliminates tools frequently exploited during container escapes or remote code execution (e.g., `gcc`, `make`, `curl`, `wget`, `git`, package managers).
2. **Minimal Image Footprint**: Cuts production images from gigabytes to megabytes, accelerating deployment rollout and registry transfer speeds.
3. **CI/CD Target Flexibility**: Enables running unit tests, linting, and vulnerability scanning within dedicated stages during CI pipelines without affecting the final image.

---

## 2. Base Image Selection Matrix

Choosing the right base image balances security, footprint, and compatibility:

| Base Image Type | Example | Footprint | Libc | Best Used For | Trade-offs & Caveats |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Google Distroless** | `gcr.io/distroless/static-debian12`, `nodejs22-debian12`, `java21-debian12` | 2MB – 50MB | glibc | Statically linked binaries (Go, Rust), Java, Node.js, Python | No package manager or shell (`/bin/sh`). Debugging requires ephemeral debug containers (`crictl debug` or Docker debug). |
| **Chainguard Images** | `cgr.dev/chainguard/static`, `cgr.dev/chainguard/python` | 5MB – 40MB | glibc / musl | Zero-CVE enterprise compliance, SBOM transparency | Commercial licensing considerations for long-term patch streams. |
| **Alpine Linux** | `alpine:3.20` | ~7MB | musl | Lightweight services, utilities, small shell environments | `musl libc` can degrade performance or cause subtle memory fragmentation issues with memory allocators (e.g. jemalloc vs musl malloc) or Python C-extensions (wheel compatibility). |
| **Debian Slim** | `debian:bookworm-slim` | ~75MB | glibc | Complex C/C++ extensions, native libraries, legacy compatibility | Larger attack surface; requires strict cleanup (`rm -rf /var/lib/apt/lists/*`) after installing packages. |
| **Scratch** | `FROM scratch` | 0MB | None | Purely static, self-contained binaries (Go, Rust with musl/static linking) | Completely empty; requires bundling CA root certificates (`ca-certificates`) and timezone databases manually if needed. |

---

## 3. Base Image Pinning & Immutability

### Anti-Pattern: Mutable and Floating Tags
```dockerfile
# ❌ Flaky, non-reproducible, vulnerable to supply chain drift
FROM node:latest
FROM python:3
FROM alpine
```

### Best Practice: Explicit Semantic Tags or SHA256 Digests
```dockerfile
# ✅ Pinned semantic version with OS distribution
FROM node:22.12.0-alpine3.20

# ✅ Highest security & reproducibility: Content-addressed digest
FROM gcr.io/distroless/base-debian12:nonroot@sha256:74ddbf52d6873e32830509930f166fb931d2da3924386f297b1830a27207dd43
```

---

## 4. Multi-Stage Target Patterns in CI

Leverage multi-stage targeting to execute test suites and linters directly in BuildKit without shipping test dependencies to production:

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim-bookworm AS base
WORKDIR /app
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1
COPY --from=ghcr.io/astral-sh/uv:0.5.24 /uv /bin/uv

FROM base AS deps
RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=cache,target=/root/.cache/uv \
    uv venv /app/.venv && uv sync --frozen --no-dev --no-install-project

# Dedicated test stage for CI pipelines
FROM deps AS test
RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen
COPY . .
RUN /app/.venv/bin/pytest tests/ && /app/.venv/bin/ruff check .

# Production runner stage
FROM python:3.12-slim-bookworm AS runner
WORKDIR /app
RUN groupadd -g 10001 appgroup && useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser
COPY --from=deps /app/.venv /app/.venv
COPY --chown=10001:10001 src/ /app/src/
USER 10001:10001
ENTRYPOINT ["/app/.venv/bin/python", "-m", "src.main"]
```

### Running Test Target in CI:
```bash
# Runs only up to the 'test' stage; skips building the final production runner
docker build --target test -t my-app:test .
```

---

## 5. Spring Boot 3 Layered Jars Multi-Stage Pattern

In Java enterprise microservices, recompiling source code should not force re-downloading hundreds of megabytes of third-party libraries across Docker layer caches. Spring Boot 3.3+ provides layered JAR extraction:

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /workspace

# Step 1: Cache Gradle wrapper and dependencies
COPY gradlew gradlew.bat settings.gradle.kts build.gradle.kts ./
COPY gradle/ gradle/
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    ./gradlew dependencies --no-daemon

# Step 2: Build the executable bootJar
COPY src/ src/
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    ./gradlew bootJar --no-daemon -x test

# Step 3: Extract JAR into discrete architectural layers
RUN java -Djarmode=tools -jar build/libs/*.jar extract --layers --destination extracted/

# Step 4: Assemble minimal runtime container
FROM eclipse-temurin:21-jre-alpine AS runner
WORKDIR /app
RUN addgroup -g 10001 -S appgroup && adduser -u 10001 -S appuser -G appgroup

# Copy layers in order of change frequency: dependencies almost never change; application changes every build
COPY --from=builder --chown=10001:10001 /workspace/extracted/dependencies/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/application/ ./

USER 10001:10001
EXPOSE 8080
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

---

## 6. Artifact Transfer Discipline (`COPY --from`)

When copying artifacts from builder stages to the runner stage:
- **Copy only what is required at runtime**: Do not copy entire working directories (`COPY --from=builder /app /app` ❌).
- **Set ownership at copy time**: Use `--chown=<user>:<group>` to avoid adding redundant image layers through subsequent `RUN chown -R ...` commands.
- **Preserve file permissions**: Ensure binary executables retain execute permissions (`chmod +x`).

```dockerfile
# ✅ Efficient and clean: sets ownership without bloating layers
COPY --from=builder --chown=nonroot:nonroot /src/bin/server /usr/local/bin/server
```
