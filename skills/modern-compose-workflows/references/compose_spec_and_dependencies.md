# Compose Spec & Dependency Synchronization Guide

Docker Compose has evolved from a tool tied to specific file version schemas (`version: '2'`, `version: '3.8'`) into the open, versionless **Compose Specification**.

---

## 1. The Versionless Compose Specification

### Deprecating the `version` Attribute
The top-level `version` attribute is deprecated and obsolete:
```yaml
# ❌ Obsolete syntax:
version: '3.8'
services:
  ...

# ✅ Modern Compose Spec (versionless):
name: my-project
services:
  ...
```
Modern Docker Compose (v2.x CLI) ignores the `version` field or outputs deprecation warnings. Omit it completely.

### The Top-Level `name:` Attribute
Always define an explicit top-level `name:` attribute. By default, Compose uses the base name of the project directory. In CI environments or git worktrees where repository folders may be named `workspace-1`, `repo_head`, or `job-1234`, omitting `name:` results in dynamic, unpredictable network and volume prefixes.

### Standard File Naming Precedence
Docker Compose searches for configuration files in the following order:
1. `compose.yaml` (Preferred standard)
2. `compose.override.yaml` (Automatic local override)
3. `docker-compose.yaml` (Backward compatibility)
4. `docker-compose.override.yaml`

---

## 2. Dependency Synchronization with `depends_on`

### The Problem with Bare `depends_on`
A container entering the `running` state only means the container process started. It does NOT mean the database has initialized its storage engine, recovered logs, or started listening on its TCP port.
```yaml
# ❌ Anti-pattern: App crashes with connection refused because Postgres is still booting
services:
  db:
    image: postgres:16-alpine
  api:
    image: my-api:latest
    depends_on:
      - db
```

### The Solution: `condition: service_healthy`
Pair the dependency with an explicit `healthcheck` definition:
```yaml
# ✅ Robust: App waits until the database health check passes
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
  api:
    image: my-api:latest
    depends_on:
      db:
        condition: service_healthy
```

### One-Off Task Synchronization: `condition: service_completed_successfully`
When database schema migrations, seeders, or SSL certificate generation must run to completion before launching the API:
```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  migrator:
    image: my-migrator:latest
    depends_on:
      db:
        condition: service_healthy
    restart: "no" # Runs once and exits

  api:
    image: my-api:latest
    depends_on:
      db:
        condition: service_healthy
      migrator:
        condition: service_completed_successfully # Blocks until migrator exits with code 0!
```

---

## 3. Production Healthcheck Recipes for Common Services

> **Critical YAML Syntax Rule**: In Compose YAML files, when referencing environment variables inside `CMD-SHELL`, escape the dollar sign as `$$` (e.g. `$${POSTGRES_USER}`) to prevent Compose from interpolating the variable on the host at parse time instead of inside the container at runtime.

### PostgreSQL
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-postgres}"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 10s
```

### Redis
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
```

### MySQL 8+ / MariaDB
```yaml
healthcheck:
  test: ["CMD-SHELL", "mysqladmin ping -h localhost -u root --silent || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 20s
```

### MongoDB
```yaml
healthcheck:
  test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')", "--quiet"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 10s
```

### RabbitMQ
```yaml
healthcheck:
  test: ["CMD", "rabbitmq-diagnostics", "-q", "check_running"]
  interval: 15s
  timeout: 10s
  retries: 5
  start_period: 20s
```

### Kafka / Redpanda
```yaml
# Redpanda (lightweight Kafka alternative)
healthcheck:
  test: ["CMD-SHELL", "rpk cluster health | grep -q 'Healthy:.*true'"]
  interval: 15s
  timeout: 5s
  retries: 5
  start_period: 15s
```

### HTTP Service (Alpine Wget vs Curl)
```yaml
# Alpine-based services (curl absent, wget present)
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/actuator/health || exit 1"]
  interval: 15s
  timeout: 3s
  retries: 3
  start_period: 15s
```
