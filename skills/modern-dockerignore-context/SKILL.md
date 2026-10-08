---
name: modern-dockerignore-context
description: >-
  Use this skill when configuring, auditing, or optimizing Docker build contexts and .dockerignore files:
  context size reduction, BuildKit client-side filtering, whitelist (allowlist) ignore patterns,
  security leakage prevention (.git, .env), and per-Dockerfile ignore rules.
---

# Modern Docker Context & `.dockerignore` Hygiene

This skill provides production standards, pattern recipes, and security controls for managing Docker build contexts and `.dockerignore` files.

---

## Core Engineering Principles

1. **Context Whitelisting by Default**:
   - Prefer the **whitelist (allowlist) pattern**: ignore everything with `**`, then selectively un-ignore (`!`) only the manifests and source directories strictly required for compilation.
   - Whitelisting ensures that newly added files, test fixtures, scripts, or local secret files are never inadvertently shipped into container images.

2. **Absolute Ban on Leaking Sensitive Assets**:
   - Never allow `.git/` into the build context: it bloats context transfer by hundreds of megabytes and exposes entire commit histories containing historical secrets or private branches.
   - Never allow `.env`, `.env.*`, `*.pem`, `*.key`, `id_rsa*`, or cloud credentials (`.aws/`, `.kube/`) into the build context.
   - To inject Git commit SHA or version metadata, use BuildKit build arguments (`--build-arg COMMIT_SHA=...`), NEVER `.git/`.

3. **Exclude Build Outputs and Local Dependencies**:
   - Always exclude locally generated compilation artifacts (`dist/`, `target/`, `build/`, `bin/`) and local dependency trees (`node_modules/`, `.venv/`, `vendor/`).
   - Compilation and dependency fetching must be performed inside the container using multi-stage builds and cache mounts, guaranteeing host-independent reproducibility.

4. **Accelerate BuildKit Context Transfer**:
   - An unoptimized build context wastes network bandwidth and CPU cycles hashing unnecessary files before the build even begins.
   - Clean context boundaries ensure that Docker layer cache calculations remain stable, avoiding cache invalidation caused by timestamp changes in unrelated files.

---

## Directory Resources & References

- **Detailed Guides**:
  - [Context Optimization & Whitelist Pattern Guide](./references/context_optimization_and_whitelisting.md)
- **Ready-to-Use Templates**:
  - [Production Whitelist .dockerignore Template](./resources/dockerignore-whitelist.template)
  - [Universal Blacklist .dockerignore Template](./resources/dockerignore-universal-blacklist.template)

---

## Production Golden Templates

### Template A: The Whitelist (Allowlist) Pattern (Recommended)
This approach is the most robust and secure. It ignores all files by default and explicitly declares allowed paths:

```dockerignore
# 1. Ignore everything across the entire repository recursively
**

# 2. Re-include project build manifests
!package.json
!package-lock.json
!tsconfig.json

# 3. Re-include source directory and public assets recursively
!src/**
!public/**

# 4. Safeguard: Re-exclude common sensitive patterns even if inside allowed folders
**/.DS_Store
**/*.log
**/.env*
```

### Template B: Enterprise Universal Blacklist Template
When projects have dynamic directory structures where whitelisting is impractical:

```dockerignore
# =============================================================================
# Version Control & CI/CD
# =============================================================================
.git/
.gitignore
.gitattributes
.github/
.gitlab/

# =============================================================================
# Environment Variables & Credentials (CRITICAL SECURITY)
# =============================================================================
.env
.env.*
!.env.example
*.pem
*.key
*.crt
*.pfx
*id_rsa*
.aws/
.kube/
.npmrc
.pypirc

# =============================================================================
# Dependency Directories & Package Caches
# =============================================================================
node_modules/
.pnpm-store/
.yarn/
vendor/
.venv/
venv/
__pycache__/
*.pyc

# =============================================================================
# Build Artifacts, Compilations & Caches
# =============================================================================
dist/
build/
out/
target/
.gradle/
.turbo/
.next/
.nuxt/
.cache/

# =============================================================================
# IDE, Editor & Operating System Artifacts
# =============================================================================
.idea/
.vscode/
*.swp
*.swo
.DS_Store
Thumbs.db

# =============================================================================
# Test Results, Coverage & Logs
# =============================================================================
coverage/
.nyc_output/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
```
