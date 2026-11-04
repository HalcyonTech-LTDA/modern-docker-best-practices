<div align="center">

<a href="https://www.halcyontech.com.br/" target="_blank" rel="noopener noreferrer">
  <img src="assets/halcyon-horizontal-cor.svg" alt="Halcyon Tech" height="60">
</a>

# Modern Docker Best Practices Plugin
### Container Engineering, Multi-Stage BuildKit & Rootless Security Standards

[![Antigravity Plugin](https://img.shields.io/badge/Antigravity-Plugin%20v1.0.0-4F46E5.svg)](https://antigravity.google)
[![License: MIT](https://img.shields.io/badge/License-MIT-10B981.svg)](./LICENSE)
[![Website](https://img.shields.io/badge/Website-halcyontech.com.br-008080.svg)](https://www.halcyontech.com.br/)
[![Organization](https://img.shields.io/badge/Organization-HalcyonTech--LTDA-black.svg)](https://github.com/HalcyonTech-LTDA)

<p align="center">
  <b>Professional modern Docker best practices covering secure and optimized Dockerfile engineering (BuildKit, multi-stage builds, non-root users, cache/secret mounts), modern Compose Spec orchestration (compose.yaml / docker-compose.yaml, healthcheck choreography, network segmentation, Compose Watch), and lean build context filtering with .dockerignore whitelisting.</b>
</p>

</div>

---

## Installation & Verification

### Antigravity CLI (`agy`)

Install directly into your Antigravity environment via the CLI:

```bash
agy plugin install https://github.com/HalcyonTech-LTDA/modern-docker-best-practices
```

Verify that the plugin is active and adheres to the strict official schema:

```bash
agy plugin list
agy plugin validate --strict ./modern-docker-best-practices
```

---

## Overview

Modern container engineering demands speed, minimal attack surfaces, supply-chain reproducibility, and deterministic local orchestration. This plugin establishes production standards across three essential pillars:

1. **`Dockerfile` Engineering**: BuildKit multi-stage builds, non-root execution, package cache mounts, secret mounts, PID 1 signal management, `STOPSIGNAL`, immutable base images, and polyglot templates (Node.js, Go, Python with `uv`, Java 21 Spring Boot layered jars).
2. **`compose.yaml` Orchestration**: Versionless Compose Spec compliance, healthcheck choreography (`condition: service_healthy`), one-off task execution (`condition: service_completed_successfully`), isolated internal networks (`internal: true`), `stop_grace_period` termination safety, and fast local development loops with Compose Watch.
3. **`.dockerignore` Context Optimization**: Client-side build context pruning, the whitelist allowlist pattern, preventing credential leakage (`.git`, `.env*`), cache stabilization, and passing Git metadata safely via `--build-arg`.

---

---

## What's Included (Component Catalog)

### Contextual Rules (`rules/`)
Automatically loaded to govern and protect project contexts:
- **[`modern-docker-engineering.md`](rules/modern-docker-engineering.md)**: Automatically enforces modern Docker engineering standards, BuildKit multi-stage Dockerfiles, non-root/rootless containers, modern Compose Spec orchestration (compose.yaml / docker-compose.yaml), healthcheck choreography, network segmentation, and lean build context filtering with .dockerignore.

### Procedural Skills (`skills/`)
On-demand actionable workflows and runbooks:
- **[`/modern-compose-workflows`](skills/modern-compose-workflows/SKILL.md)**: Use this skill when designing, reviewing, or debugging Docker Compose configurations: Compose Spec compliance, healthcheck choreography (service_healthy, service_completed_successfully), network segmentation (internal networks), volume isolation, security hardening, environment variables, Compose Watch, and profiles.
- **[`/modern-dockerfile-craftsmanship`](skills/modern-dockerfile-craftsmanship/SKILL.md)**: Use this skill when authoring, auditing, optimizing, or refactoring Dockerfiles: BuildKit syntax, multi-stage builds, non-root execution, distroless and minimal base images, layer caching, cache and secret mounts, PID 1 signal propagation, STOPSIGNAL, and container healthchecks.
- **[`/modern-dockerignore-context`](skills/modern-dockerignore-context/SKILL.md)**: Use this skill when configuring, auditing, or optimizing Docker build contexts and .dockerignore files: context size reduction, BuildKit client-side filtering, whitelist (allowlist) ignore patterns, security leakage prevention (.git, .env), and per-Dockerfile ignore rules.

---

## Directory Hierarchy

```text
modern-docker-best-practices/
├── plugin.json              # Official Antigravity manifest (schema v1)
├── LICENSE                  # MIT License (Copyright 2026 HalcyonTech LTDA)
├── .gitignore               # System ignores & installed_version.json exclusions
├── .gitattributes           # Deterministic line endings (* text=auto eol=lf)
├── README.md                # Golden Standard documentation & runbook
├── assets/
│   ├── logo.svg             # Antigravity marketplace square icon
│   └── halcyon-horizontal-cor.svg # Official Halcyon Tech brand logo (white background)             # Official Halcyon Tech corporate vector symbol
├── rules/                   # Contextual rules discovered automatically
│   └── modern-docker-engineering.md
├── skills/                  # Actionable procedural skills (Progressive Disclosure)
│   └── modern-compose-workflows/
│       └── SKILL.md
│   └── modern-dockerfile-craftsmanship/
│       └── SKILL.md
│   └── modern-dockerignore-context/
│       └── SKILL.md
```

---

## 💡 Prompt Recipes & Use Cases

```markdown
- "Optimize this Dockerfile for multi-stage builds, caching, and minimal footprint"
- "Audit container security, non-root user execution, and vulnerability scanning"
- "Generate production-grade Docker Compose configurations with healthchecks"
```

---

## 📄 License & Corporate Governance

Distributed under the **MIT License**. Copyright (c) 2026 **HalcyonTech LTDA**.  
Engineered with precision and excellence by [Halcyon Tech](https://www.halcyontech.com.br/) &mdash; [GitHub Organization](https://github.com/HalcyonTech-LTDA).
