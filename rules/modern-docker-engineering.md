---
description: Automatically enforces modern Docker engineering standards, BuildKit multi-stage Dockerfiles, non-root/rootless containers, modern Compose Spec orchestration (compose.yaml / docker-compose.yaml), healthcheck choreography, network segmentation, and lean build context filtering with .dockerignore.
trigger: model_decision
---

# Modern Docker Engineering Guardrails & Skill Router

When authoring, reviewing, or refactoring Dockerfiles, Docker Compose files, container architectures, or image build contexts, strictly adhere to Modern Docker Engineering Standards and the corresponding specialized skills:

| When working on... | Consult & Activate Skill | Key Focus Areas |
| :--- | :--- | :--- |
| **Dockerfile Engineering & Hardening** | `modern-dockerfile-craftsmanship` | BuildKit multi-stage builds, non-root users, distroless/minimal images, cache & secret mounts, exec form, and `HEALTHCHECK`. |
| **Docker Compose Orchestration** | `modern-compose-workflows` | Versionless Compose Spec (`compose.yaml`), service choreography (`service_healthy`), internal network isolation, and Compose Watch. |
| **Build Context & Ignore Hygiene** | `modern-dockerignore-context` | Whitelist filtering pattern (`**` then `!`), build context acceleration, and zero secret leakage prevention. |

---

## Non-Negotiable Guardrails (Absolute Invariants)

1. **Versionless Compose Spec Standard**: Prohibit deprecated top-level `version:` attributes in Compose files. Use the canonical filename `compose.yaml` (with `docker-compose.yaml` fallback) and define an explicit top-level `name:`.
2. **Absolute Ban on Root Execution & Production Hardening**: Application containers must execute as an unprivileged system user (UID != 0). Production containers must enforce read-only filesystems (`read_only: true`), drop unnecessary Linux capabilities (`cap_drop: [ALL]`), and set `security_opt: [no-new-privileges:true]`.
3. **BuildKit Multi-Stage Architecture & Immutable Pinning**: Always include `# syntax=docker/dockerfile:1`. Decouple build tools from runtime via multi-stage builds (`builder`/`runner`) and pin base images to immutable semantic tags or digests (ban `:latest`).
4. **Signal Propagation & Strict Exec Form**: Mandate exec form (JSON array syntax) for `ENTRYPOINT` and `CMD`. Prohibit shell form syntax to prevent wrapping processes in `/bin/sh` and breaking POSIX termination signals (`SIGTERM`).
5. **Zero Baked Secrets & Default-Deny Build Context**: Never inject credentials into image layers or build contexts (use BuildKit secret mounts or runtime secrets). Every context must include a `.dockerignore` utilizing the default-deny whitelist pattern.
6. **Healthcheck Choreography & Network Isolation**: Backing dependencies must define lightweight healthchecks, and dependents must declare `condition: service_healthy`. Isolate databases and internal services on non-exported bridge networks without exposing host ports.

Consult the corresponding skills for complete technical deep dives, configuration recipes, and reference implementations.
