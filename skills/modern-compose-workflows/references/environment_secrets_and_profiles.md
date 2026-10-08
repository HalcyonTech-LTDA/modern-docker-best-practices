# Environment Variables, Secrets & Compose Profiles Guide

Proper configuration and secret management prevents accidental data leakage, simplifies environment transitions, and protects infrastructure from credential theft.

---

## 1. Environment Variable Interpolation Discipline

Docker Compose supports POSIX-style variable expansion. Use strict interpolation modifiers to enforce environment validation at startup.

### Interpolation Operators

| Operator | Syntax | Behavior |
| :--- | :--- | :--- |
| **Strict Assertion** | `${DB_PASSWORD:?DB_PASSWORD must be provided}` | Exits with error if `DB_PASSWORD` is unset or empty. |
| **Default Fallback** | `${PORT:-8080}` | Uses `8080` if `PORT` is unset or empty. |
| **Alternate Value** | `${DEBUG:+--verbose}` | Uses `--verbose` only if `DEBUG` is set; empty otherwise. |

### The `.env.example` Policy
- **Never commit `.env`**: Always add `.env` and `.env.*.local` to `.gitignore` and `.dockerignore`.
- **Mandate `.env.example`**: Maintain an exhaustive `.env.example` file in the project root documenting all supported variables with non-sensitive defaults or dummy placeholders:

```bash
# .env.example
APP_ENV=development
APP_PORT=8080
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=development_db
DB_USER=appuser
DB_PASSWORD=change_me_in_production
```

---

## 2. Secrets Management with Docker Compose

Passing credentials via plain environment variables (`environment: DB_PASSWORD=secret`) is an anti-pattern: environment variables are easily exposed via `docker inspect`, `/proc/<pid>/environ`, and application crash logs.

### File-Based Secrets Pattern
Compose provides first-class `secrets:` definitions that mount sensitive data as temporary files under `/run/secrets/` inside the container:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: appuser
      POSTGRES_DB: appdb
      # Tell PostgreSQL to read the password from the secret file
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

  api:
    image: my-api:latest
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

---

## 3. Configs Management (`configs:`)

Similar to secrets, application configuration files (e.g., Nginx configurations, Prometheus scrape targets) can be mounted using the top-level `configs:` block:

```yaml
services:
  gateway:
    image: nginx:alpine
    configs:
      - source: nginx_conf
        target: /etc/nginx/nginx.conf
        mode: 0444 # Read-only permission

configs:
  nginx_conf:
    file: ./nginx.conf
```

---

## 4. Compose Profiles (`profiles:`)

Profiles allow you to selectively activate auxiliary services (e.g. administrative UIs, mock servers, migrations, debuggers, monitoring tools) without running them by default.

```yaml
services:
  api:
    image: my-api:latest
    ports:
      - "8080:8080"

  # Auxiliary database UI: Only runs when 'tools' profile is active
  pgadmin:
    image: dpage/pgadmin4:latest
    profiles:
      - tools
    ports:
      - "127.0.0.1:5050:80"

  # One-time database seed script: Only runs when 'seed' profile is active
  db-seeder:
    image: my-seeder:latest
    profiles:
      - seed
    depends_on:
      api:
        condition: service_healthy
```

### Running with Profiles:
```bash
# Starts only default services (api)
docker compose up -d

# Starts default services PLUS pgadmin
docker compose --profile tools up -d

# Runs only the db-seeder
docker compose --profile seed run db-seeder

# Enable via environment variable
export COMPOSE_PROFILES=tools,monitoring
docker compose up -d
```
