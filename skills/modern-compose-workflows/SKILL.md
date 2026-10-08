---
name: modern-compose-workflows
description: >-
  Use this skill when designing, reviewing, or debugging Docker Compose configurations:
  Compose Spec compliance, healthcheck choreography (service_healthy, service_completed_successfully),
  network segmentation (internal networks), volume isolation, security hardening, environment variables, Compose Watch, and profiles.
---

# Modern Docker Compose Orchestration & Workflows

This skill provides comprehensive patterns and production standards for orchestrating multi-container applications using the standardized Docker Compose Specification (`compose.yaml`).

---

## Core Engineering Principles

1. **Versionless Compose Specification**:
   - Never specify `version: '3.8'` or any top-level `version` attribute. The modern Compose Specification is versionless.
   - Prefer the canonical filename `compose.yaml` over legacy `docker-compose.yaml` (both are supported; `compose.yaml` takes precedence).
   - Define a top-level `name:` attribute to prevent ambiguous project naming based on parent folder names.

2. **Resilient Dependency Choreography (`service_healthy` & `service_completed_successfully`)**:
   - Never use bare `depends_on: [db]` expecting databases or message brokers to be ready to accept TCP traffic.
   - Backing services must declare an explicit `healthcheck`.
   - Dependent services must declare `depends_on` with `condition: service_healthy` for persistent services, and `condition: service_completed_successfully` for one-shot database migrations or setup tasks.

3. **Strict Network Segmentation & Internal Protection**:
   - Segment services into dedicated user-defined bridge networks (e.g., `frontend_net`, `backend_net`, `data_net`).
   - Backing data stores must reside on an `internal: true` network with zero public egress or ingress.
   - Never bind database ports to host interfaces (`0.0.0.0:5432:5432` ❌) unless explicitly required for local inspection, and even then, bind strictly to localhost (`127.0.0.1:5432:5432` ✅).

4. **Container Hardening & Graceful Termination**:
   - Apply `read_only: true` with ephemeral `tmpfs` mounts for `/tmp` and `/run`.
   - Explicitly drop all capabilities (`cap_drop: [ALL]`) and enable `security_opt: [no-new-privileges:true]`.
   - Constrain compute resources using `deploy.resources.limits` (`cpus`, `memory`).
   - Declare `stop_grace_period: 30s` (or longer) on databases and critical APIs to ensure transactions flush before `SIGKILL`.

5. **Environment Variable & Secret Discipline**:
   - Use strict interpolation (`${VARIABLE:?Environment variable VARIABLE must be set}`) or explicit fallbacks (`${VARIABLE:-default}`).
   - Maintain a synchronized `.env.example` file at the project root.
   - Mount credentials via top-level `secrets:`, accessible at `/run/secrets/<name>` inside containers.

6. **Modern Developer Feedback Loops (Compose Watch)**:
   - Replace complex manual volume mounts with `develop.watch` definitions.
   - Use `action: sync` for static assets, `action: sync+restart` for backend source code, and `action: rebuild` for manifest changes.
   - Pair with `compose.override.yaml` for local development overlays while keeping base `compose.yaml` production-ready.

---

## Directory Resources & References

- **Detailed Guides**:
  - [Compose Spec & Dependency Synchronization](./references/compose_spec_and_dependencies.md)
  - [Network Segmentation, Volumes & Security](./references/networking_volumes_and_security.md)
  - [Environment Variables, Secrets & Profiles](./references/environment_secrets_and_profiles.md)
  - [Developer Experience & Compose Watch](./references/developer_experience_and_watch.md)
- **Production Reference Implementations**:
  - [Production-Grade Multi-Tier compose.yaml](./examples/compose.yaml)
  - [Developer Local Overlay compose.override.yaml](./examples/compose.override.yaml)
- **Checklists & Tools**:
  - [Backing Service Healthcheck Cheatsheet](./resources/compose-healthcheck-cheatsheet.md)

---

## Production Golden Template (`compose.yaml`)

```yaml
# Note: No 'version' key! The Compose Spec is versionless.
name: enterprise-platform

services:
  # ---------------------------------------------------------------------------
  # Backing Data Store (Isolated, Health-Checked & Safe Stop)
  # ---------------------------------------------------------------------------
  db:
    image: postgres:16.4-alpine3.20
    restart: unless-stopped
    stop_grace_period: 30s
    environment:
      POSTGRES_DB: ${DB_NAME:-appdb}
      POSTGRES_USER: ${DB_USER:-appuser}
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - data_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: "1.5"
          memory: 1024M

  # ---------------------------------------------------------------------------
  # One-Off Migration Runner (Runs Once and Exits with 0)
  # ---------------------------------------------------------------------------
  migrator:
    image: migrate/migrate:v4.18.2
    restart: "no"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - data_net
    secrets:
      - db_password
    command: ["-path=/migrations", "-database=postgres://${DB_USER:-appuser}@db:5432/${DB_NAME:-appdb}?sslmode=disable", "up"]

  # ---------------------------------------------------------------------------
  # Core Application Service (Hardened & Choreographed)
  # ---------------------------------------------------------------------------
  api:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    stop_grace_period: 20s
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m
      - /run:rw,noexec,nosuid,size=16m
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    environment:
      PORT: 8080
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${DB_NAME:-appdb}
      DB_USER: ${DB_USER:-appuser}
    secrets:
      - db_password
    networks:
      - data_net
      - public_net
    ports:
      - "127.0.0.1:8080:8080" # Bound strictly to localhost loopback
    depends_on:
      db:
        condition: service_healthy
      migrator:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD", "/app/healthcheck"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 5s

secrets:
  db_password:
    file: ./secrets/db_password.txt

volumes:
  postgres_data:

networks:
  public_net:
    driver: bridge
  data_net:
    driver: bridge
    internal: true # Isolates database from external internet access
```
