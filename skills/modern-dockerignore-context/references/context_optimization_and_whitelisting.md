# Build Context Optimization & Whitelist Guide

The Docker build context is the set of files located at the path or URL specified to `docker build [PATH]`. Managing this context via `.dockerignore` is essential for build performance, layer cache stability, and container supply chain security.

---

## 1. Mechanics of the Build Context

When invoking `docker build .`:
1. The Docker CLI evaluates the `.dockerignore` file in the context root directory.
2. In modern BuildKit, client-side filtering analyzes referenced `COPY` and `ADD` instructions, transferring **only the files actually needed by the build steps** across the daemon socket.
3. If `.dockerignore` is missing, BuildKit must calculate checksums for the entire directory tree, which can cause severe build latency on large repositories.

---

## 2. The Whitelist (Invert / Allowlist) Pattern

Traditional `.dockerignore` files use a blacklist approach (listing files to exclude). As projects evolve, new directories (e.g., test scripts, data dumps, credentials) are frequently created and accidentally captured by broad `COPY . .` instructions.

The **whitelist pattern** reverses this: it excludes everything by default and explicitly defines the allowable surface area.

### Whitelist Architecture:
```dockerignore
# Step 1: Recursively exclude everything across the entire repository
**

# Step 2: Un-exclude top-level project descriptors
!package.json
!package-lock.json
!tsconfig.json

# Step 3: Un-exclude source code directories recursively
!src/**
!public/**

# Step 4: Defense-in-depth: Re-exclude sensitive patterns inside un-excluded directories
**/.DS_Store
**/*.log
**/.env*
```

### Pattern Matching Rules (Go filepath.Glob + `**`):
- `*` matches any sequence of non-separator characters (single directory level).
- `**` matches an arbitrary number of nested directories (recursive).
- `!` negates a previous pattern (un-ignores).
- Leading and trailing slashes are sanitized; `!src/**` matches `src/` and all nested contents.
- Rules are evaluated **top-to-bottom**; later patterns override earlier ones.

---

## 3. Polyglot Whitelist Recipes

### A. Go Microservice Whitelist
```dockerignore
**
!go.mod
!go.sum
!cmd/**
!internal/**
!pkg/**
!api/**
```

### B. Java / Gradle Microservice Whitelist
```dockerignore
**
!gradlew
!gradlew.bat
!gradle/**
!build.gradle.kts
!settings.gradle.kts
!src/**
```

### C. Python / uv / Poetry Whitelist
```dockerignore
**
!pyproject.toml
!uv.lock
!poetry.lock
!src/**
```

---

## 4. Security Critical: Why `.git` Must Always Be Ignored

Never permit the `.git/` directory to enter a container image:
1. **Full History Exposure**: Even if you delete a secret or `.env` file in a subsequent commit, `.git` retains the compressed delta of all historical files. Anyone with access to the container image can run `git log -p` or unpack packfiles to extract past credentials.
2. **Context Bloat**: In mature repositories, `.git/` can easily reach multiple gigabytes, causing severe transfer delays.
3. **Cache Invalidation**: Every git branch switch, checkout, or commit changes `.git/index` and `.git/HEAD`, permanently invalidating Docker layer caches on broad `COPY` steps.

---

## 5. Safely Injecting Git Metadata Without `.git`

When an application binary or OCI label requires the current commit SHA or version:

### Anti-Pattern: Un-ignoring `.git`
```dockerfile
# ❌ Anti-pattern: Copies full commit history and destroys layer cache
COPY .git .git
RUN git rev-parse --short HEAD > /app/version
```

### Best Practice: Build Arguments (`--build-arg`)
Pass metadata from the host environment:
```dockerfile
ARG COMMIT_SHA=unknown
LABEL org.opencontainers.image.revision=$COMMIT_SHA
ENV APP_VERSION=$COMMIT_SHA
```

```bash
docker build \
  --build-arg COMMIT_SHA=$(git rev-parse --short HEAD) \
  -t my-service:latest .
```

---

## 6. Per-Dockerfile Ignore Files in BuildKit

BuildKit supports target-specific `.dockerignore` files when multiple Dockerfiles exist in the same repository:

```text
my-project/
├── Dockerfile.frontend
├── Dockerfile.frontend.dockerignore
├── Dockerfile.backend
└── Dockerfile.backend.dockerignore
```

When building `Dockerfile.frontend`:
```bash
docker build -f Dockerfile.frontend .
```
BuildKit automatically detects and applies `Dockerfile.frontend.dockerignore` instead of the generic `.dockerignore`.
