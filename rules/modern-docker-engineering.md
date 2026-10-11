---
description: Automatically enforces modern Docker engineering standards, BuildKit multi-stage Dockerfiles, non-root/rootless containers, modern Compose Spec orchestration (compose.yaml / docker-compose.yaml), healthcheck choreography, network segmentation, and lean build context filtering with .dockerignore.
trigger: model_decision
---

# Modern Docker Engineering Guardrails & Skill Router

When authoring, reviewing, or refactoring Dockerfiles, Docker Compose files, container architectures, or image build contexts, strictly adhere to Modern Docker Engineering Standards and the corresponding specialized skills:

| When working on... | Consult & Activate Skill | Key Focus Areas |
| :--- | :--- | :--- |
| **Dockerfile Engineering & Hardening** | `modern-dockerfile-craftsmanship` | BuildKit multi-stage builds, non-root users, distroless/minimal images, cache & secret mounts, exec form, PID 1 signal propagation, and `HEALTHCHECK`. |
| **Docker Compose Orchestration** | `modern-compose-workflows` | Versionless Compose Spec (`compose.yaml`), service choreography (`condition: service_healthy`), internal network isolation, volume boundaries, Compose Watch, and secrets. |
| **Build Context & Ignore Hygiene** | `modern-dockerignore-context` | Whitelist filtering pattern (`**` then `!`), build context transfer acceleration, BuildKit client-side exclusion, and zero secret leakage prevention. |

---

## Non-Negotiable Guardrails (Absolute Invariants)

1. **Deprecate Top-Level `version` in Compose Files**:
   - The Compose file format is standardized as the versionless Compose Specification.
   - Do NOT include `version: '3.8'` or any top-level `version` attribute in Compose files.
   - Prefer standard canonical filename `compose.yaml` (with `docker-compose.yaml` as backwards-compatible fallback).
   - Declare an explicit top-level `name:` attribute to prevent directory-based naming collisions in CI or local environments.

2. **Absolute Ban on Root Execution in Production Containers**:
   - Never allow production application processes to run as `root` (UID 0).
   - Explicitly declare an unprivileged system user and group (e.g., `USER nonroot:nonroot` or `USER 10001:10001`).
   - Create directories and set ownership before dropping privileges; verify permissions do not require root write access.

3. **Mandate BuildKit Syntax & Multi-Stage Architecture**:
   - Always include the BuildKit syntax directive `# syntax=docker/dockerfile:1` at the very top of Dockerfiles.
   - Decouple build-time tooling (compilers, build CLIs, package managers) from the runtime environment using multi-stage builds (`AS builder`, `AS runner`).
   - Copy only finalized compiled artifacts and production dependencies into the final runtime stage.

4. **Immutable Base Images & Ban on Floating `:latest`**:
   - Never use mutable `:latest` tags or unpinned major versions in production Dockerfiles.
   - Pin specific semantic versions or immutable content hashes (e.g., `node:22.12.0-alpine3.20` or `distroless/base:nonroot@sha256:...`).
   - Prefer minimal, attack-surface-reduced base images (Google Distroless, Chainguard, Alpine, or Debian Slim).

5. **Strict Exec Form, Signal Propagation & STOPSIGNAL**:
   - Always use the exec (JSON array) syntax for `ENTRYPOINT` and `CMD`: `ENTRYPOINT ["executable"]` and `CMD ["default_param"]`.
   - Never use the shell syntax (e.g. `CMD npm start`), as it wraps the process in `/bin/sh -c`, which absorbs POSIX signals (`SIGTERM`, `SIGINT`), causing graceful shutdown failures and container termination timeouts.
   - Set `STOPSIGNAL` when the application requires a non-standard shutdown signal (e.g., `STOPSIGNAL SIGQUIT` for Nginx).
   - If the application process does not reap zombie child processes or manage signals cleanly, wrap it with an init system such as `tini` or `dumb-init`.

6. **Zero Secrets Baked into Image Layers**:
   - Never pass credentials, access tokens, API keys, or private SSH keys via `ENV`, `ARG`, or image filesystem layers.
   - Use BuildKit secret mounts (`RUN --mount=type=secret,id=...`) for build-time credentials so they never persist in intermediate or final layers.
   - Mount runtime credentials via Docker Compose `secrets:` or runtime environment variable injection.

7. **Strict Build Context Whitelisting in `.dockerignore`**:
   - Every Docker build context MUST include a `.dockerignore` file.
   - Prefer the secure whitelist pattern: ignore everything by default (`**`), then selectively negate only necessary build paths (`!src/**`, `!package.json`).
   - Absolute ban on leaking `.git/`, `.env*` files, local developer configuration, build caches, test reports, and IDE directories (`.idea/`, `.vscode/`).
   - To inject Git commit SHA or version metadata without including `.git/`, pass them via BuildKit build arguments (`ARG COMMIT_SHA` via `--build-arg COMMIT_SHA=$(git rev-parse --short HEAD)`).

8. **Resilient Healthchecks & Dependency Choreography in Compose**:
   - Never use bare `depends_on: [service]` expecting databases or downstream dependencies to be ready to accept TCP traffic.
   - Backing services MUST define explicit, lightweight `healthcheck` blocks (e.g., `pg_isready` for Postgres, `redis-cli ping` for Redis).
   - Dependents MUST declare `depends_on` with `condition: service_healthy` for persistent backing services, and `condition: service_completed_successfully` for one-shot initialization tasks (migrations, seeders).

9. **Network Segmentation & Internal Protection**:
   - Do NOT expose internal backing databases, message brokers, or caches to the host machine via `ports:` in production/staging environments.
   - Isolate sensitive data stores on custom bridge networks marked with `internal: true` to prevent unneeded egress or unauthorized access.

10. **Container Hardening & Graceful Shutdown**:
    - Enforce `read_only: true` on production containers whenever feasible, providing explicit `tmpfs` mounts for `/tmp` and `/run` if write operations are strictly necessary.
    - Drop all default Linux capabilities (`cap_drop: [ALL]`) and add back only strictly required capabilities.
    - Set `security_opt: [no-new-privileges:true]` to prevent privilege escalation attacks.
    - Declare `stop_grace_period` (e.g., `stop_grace_period: 30s` or `60s`) on database and transaction-processing services to prevent premature forced termination via `SIGKILL`.

Consult the corresponding skills for complete technical deep dives, configuration recipes, and reference implementations.
