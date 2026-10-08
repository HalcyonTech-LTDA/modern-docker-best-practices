# Developer Experience & Compose Watch Guide

Prior to Docker Compose v2.22+, local development typically required mounting entire host directories as bind mounts into containers (`volumes: [.:/app]`), which resulted in file permission friction, cross-platform filesystem event bottlenecks (especially on macOS and Windows via virtiofs/gRPC-FUSE), and polluted container environments.

Docker Compose introduces **Compose Watch** (`develop.watch`), a native file-synchronization and build-triggering subsystem.

---

## 1. How Compose Watch Works

Compose Watch monitors file modifications on the host machine and executes tailored actions without requiring manual container teardowns or continuous volume polling.

### Watch Actions

| Action | Description | Ideal For |
| :--- | :--- | :--- |
| **`sync`** | Immediately synchronizes modified files from host to the running container filesystem. | Static web assets, templates, frontend source files handled by Vite/Webpack HMR. |
| **`sync+restart`** | Synchronizes files and triggers a graceful restart of the container process. | Backend languages and frameworks that do not natively support hot code swapping. |
| **`rebuild`** | Triggers an optimized BuildKit multi-stage rebuild and restarts the container with the fresh image. | Dependency manifest changes (`package.json`, `go.mod`, `pom.xml`), new system packages. |

---

## 2. Configuration Pattern (`develop.watch`)

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
      target: dev # Target development stage containing dev tools and hot reloaders
    ports:
      - "3000:3000"
    develop:
      watch:
        # Action 1: Rebuild container image when dependencies change
        - action: rebuild
          path: ./package.json

        # Action 2: Sync and restart backend when server logic updates
        - action: sync+restart
          path: ./src/server
          target: /app/src/server

        # Action 3: Live sync for static assets (handled by internal live-reload)
        - action: sync
          path: ./public
          target: /app/public
          ignore:
            - ./public/temp/**
```

---

## 3. Development vs. Production: The Overlay Pattern (`compose.override.yaml`)

Production containers should not contain live reloaders or developer tooling. Use Compose's automatic override mechanism to separate environments:

- **`compose.yaml` (Base / Production)**: Hardened, read-only root filesystems, stripped of development dependencies, optimized for CI and production deployments.
- **`compose.override.yaml` (Local Dev Overlay)**: Automatically applied when running `docker compose up` locally. Adds `develop.watch`, exposed local ports, and targets development stages.

### Example `compose.override.yaml`:
```yaml
services:
  api:
    build:
      target: dev # Uses the intermediate development stage with hot reloader
    read_only: false # Permitted for local hot-reload file writes
    ports:
      - "127.0.0.1:8080:8080"
      - "127.0.0.1:5005:5005" # Remote debugger port
    develop:
      watch:
        - action: rebuild
          path: ./package.json
        - action: sync+restart
          path: ./src
          target: /app/src
```

---

## 4. Running Compose Watch

### Starting in Watch Mode:
```bash
# Launch services and start watching in a single command:
docker compose up --watch

# Or run watch as a dedicated background process attached to existing services:
docker compose up -d
docker compose watch
```

---

## 5. Best Practices for High Performance Watch Loops

1. **Ignore Local Artifacts**:
   Always specify `ignore` rules for temporary output directories, cache folders, test outputs, and log files to prevent cascading rebuild cycles:
   ```yaml
   - action: sync
     path: ./src
     target: /app/src
     ignore:
       - node_modules/
       - .git/
       - "*.log"
   ```

2. **Combine with BuildKit Cache Mounts**:
   When using `action: rebuild`, ensure your `Dockerfile` utilizes `RUN --mount=type=cache` for package managers. This guarantees that dependency rebuilds take only 2–3 seconds rather than redownloading all dependencies from scratch.

3. **Avoid Over-Broad Paths**:
   Never set `path: .` with `action: rebuild`. Explicitly point to specific dependency manifests or configuration files.
