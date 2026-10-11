# Modern Docker Best Practices Plugin

An Antigravity plugin providing automated engineering guardrails, architectural patterns, security controls, and procedural skills for modern Docker engineering: BuildKit multi-stage Dockerfiles, rootless/non-root container execution, modern Compose Specification orchestration (`compose.yaml` / `docker-compose.yaml`), and lean build context filtering with `.dockerignore`.

---

## Installation

### Antigravity

Install directly in Antigravity via the CLI:

```bash
agy plugin install https://github.com/HalcyonTech-LTDA/modern-docker-best-practices
```

Verify that the plugin is installed and ready:

```bash
agy plugin list
```

### Claude Code

Add the Halcyon Tech marketplace once, then install the plugin:

```text
/plugin marketplace add HalcyonTech-LTDA/halcyon-plugins
/plugin install modern-docker-best-practices@halcyon-plugins
```

Skills are namespaced by plugin in Claude Code (`/modern-docker-best-practices:<skill-name>`). The guardrails in `rules/` load through the skills in `claude/skills/`.

---
## Overview

Modern container engineering demands speed, minimal attack surfaces, supply-chain reproducibility, and deterministic local orchestration. This plugin establishes production standards across three essential pillars:

1. **`Dockerfile` Engineering**: BuildKit multi-stage builds, non-root execution, package cache mounts, secret mounts, PID 1 signal management, `STOPSIGNAL`, immutable base images, and polyglot templates (Node.js, Go, Python with `uv`, Java 21 Spring Boot layered jars).
2. **`compose.yaml` Orchestration**: Versionless Compose Spec compliance, healthcheck choreography (`condition: service_healthy`), one-off task execution (`condition: service_completed_successfully`), isolated internal networks (`internal: true`), `stop_grace_period` termination safety, and fast local development loops with Compose Watch.
3. **`.dockerignore` Context Optimization**: Client-side build context pruning, the whitelist allowlist pattern, preventing credential leakage (`.git`, `.env*`), cache stabilization, and passing Git metadata safely via `--build-arg`.

---

## What's Included

### 1. Automatic Guardrails (`rules/modern-docker-engineering.md`)
Automatically enforced across all Docker projects:
- **Versionless Compose Specification**: Absolute ban on obsolete `version: '3.8'` headers; explicit project `name:`.
- **Production Non-Root Requirement**: Mandating unprivileged users (`USER nonroot:nonroot` or `USER 10001:10001`).
- **BuildKit Multi-Stage Mandate**: Requiring `# syntax=docker/dockerfile:1` and separating build tools from runtime containers.
- **Ban on Floating Tags**: Disallowing `:latest` or unpinned major versions; enforcing semantic tags or SHA256 digests.
- **Exec Form & Signal Handling**: Enforcing JSON array exec form (`ENTRYPOINT ["bin", "arg"]`), init managers (`tini`), and `STOPSIGNAL` declarations.
- **Zero In-Image Secrets**: Banning `ARG`/`ENV` secrets; requiring `RUN --mount=type=secret`.
- **Mandatory Build Context Filtering**: Enforcing `.dockerignore` whitelisting, barring `.git` / `.env*` from images, and injecting Git metadata via `--build-arg`.
- **Dependency Health Choreography**: Mandating `depends_on: { condition: service_healthy }` and `{ condition: service_completed_successfully }`.
- **Network Segmentation & Isolation**: Requiring `internal: true` for backing datastores with no public port exposure.
- **Container Hardening & Stop Grace Periods**: Applying `read_only: true`, `security_opt: [no-new-privileges:true]`, `cap_drop: [ALL]`, and `stop_grace_period: 30s`.

### 2. Specialized Skills (`skills/`)

#### 🛠️ `modern-dockerfile-craftsmanship`
Guides authoring, auditing, and optimizing production Dockerfiles:
- **References**:
  - `references/multistage_builds_and_images.md`: Multi-stage pipeline architecture, base image selection matrix (Distroless vs. Chainguard vs. Alpine vs. Debian Slim), and Spring Boot layered jars.
  - `references/buildkit_caching_and_secrets.md`: Package manager cache mounts (apt, apk, npm, pnpm, pip, uv, go, gradle), zero-leak secret mounts, bind mounts, and safe Git metadata passing.
  - `references/security_and_runtime.md`: Non-root user provisioning, PID 1 zombie reaping, `STOPSIGNAL` graceful termination, read-only root filesystems, and curl-free healthchecks.
- **Examples**:
  - `examples/node.Dockerfile`: Hardened Node.js TypeScript multi-stage build.
  - `examples/go.Dockerfile`: High-performance Go static binary with cross-compilation.
  - `examples/python-uv.Dockerfile`: Fast Python microservice using `uv`.
  - `examples/java-spring-boot.Dockerfile`: Spring Boot 3 / Java 21 layered jar extraction with Temurin JRE.
- **Resources**:
  - `resources/dockerfile-hardening-checklist.md`: Audit checklist for pipeline verification.

#### 🎼 `modern-compose-workflows`
Guides multi-container orchestration with Docker Compose:
- **References**:
  - `references/compose_spec_and_dependencies.md`: Versionless Compose specification standards, dependency choreography, and healthcheck recipes.
  - `references/networking_volumes_and_security.md`: Multi-tier network architecture with `internal: true`, volume persistence, `stop_grace_period`, and capability dropping.
  - `references/environment_secrets_and_profiles.md`: Strict environment variable interpolation (`:-`, `:?`), file-based secrets, application configs, and Compose profiles.
  - `references/developer_experience_and_watch.md`: Fast local iteration with Compose Watch (`develop.watch`) and `compose.override.yaml` workflows.
- **Examples**:
  - `examples/compose.yaml`: Full multi-tier production stack with Postgres, Redis, migrator, and API.
  - `examples/compose.override.yaml`: Developer overlay for hot reloading and local debugging.
- **Resources**:
  - `resources/compose-healthcheck-cheatsheet.md`: Copy-pasteable healthcheck recipes for major datastores.

#### 🛡️ `modern-dockerignore-context`
Guides build context sanitization and performance optimization:
- **References**:
  - `references/context_optimization_and_whitelisting.md`: Whitelist patterns, BuildKit client-side context transfer, why `.git` must never enter images, and per-Dockerfile ignore rules.
- **Resources**:
  - `resources/dockerignore-whitelist.template`: Production whitelist `.dockerignore`.
  - `resources/dockerignore-universal-blacklist.template`: Enterprise fallback blacklist `.dockerignore`.

---

## Directory Layout

```text
modern-docker-best-practices/
├── plugin.json
├── README.md
├── rules/
│   └── modern-docker-engineering.md
└── skills/
    ├── modern-dockerfile-craftsmanship/
    │   ├── SKILL.md
    │   ├── examples/
    │   │   ├── go.Dockerfile
    │   │   ├── java-spring-boot.Dockerfile
    │   │   ├── node.Dockerfile
    │   │   └── python-uv.Dockerfile
    │   ├── references/
    │   │   ├── buildkit_caching_and_secrets.md
    │   │   ├── multistage_builds_and_images.md
    │   │   └── security_and_runtime.md
    │   └── resources/
    │       └── dockerfile-hardening-checklist.md
    ├── modern-compose-workflows/
    │   ├── SKILL.md
    │   ├── examples/
    │   │   ├── compose.override.yaml
    │   │   └── compose.yaml
    │   ├── references/
    │   │   ├── compose_spec_and_dependencies.md
    │   │   ├── developer_experience_and_watch.md
    │   │   ├── environment_secrets_and_profiles.md
    │   │   └── networking_volumes_and_security.md
    │   └── resources/
    │       └── compose-healthcheck-cheatsheet.md
    └── modern-dockerignore-context/
        ├── SKILL.md
        ├── references/
        │   └── context_optimization_and_whitelisting.md
        └── resources/
            ├── dockerignore-universal-blacklist.template
            └── dockerignore-whitelist.template
```

---

## License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.
Copyright (c) 2026 Halcyon Tech.
