# Container Security, Non-Root Hardening & Process Runtime

Running secure and reliable containers requires treating containers as immutable, isolated, and least-privileged processes.

---

## 1. Non-Root User Provisioning

Running as `root` (UID 0) inside a container is a severe security liability. If a container breakout or privilege escalation vulnerability occurs, the attacker immediately possesses root privileges on the container host (unless rootless Docker or user namespace remapping is configured).

### Debian / Ubuntu Non-Root Provisioning:
```dockerfile
# Create system group and user with deterministic high UID/GID
RUN groupadd -g 10001 appgroup \
    && useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser

# Ensure destination directories exist and have proper ownership
WORKDIR /app
RUN chown -R appuser:appgroup /app

USER 10001:10001
```

### Alpine Linux Non-Root Provisioning:
```dockerfile
RUN addgroup -g 10001 -S appgroup \
    && adduser -u 10001 -S appuser -G appgroup -s /sbin/nologin

WORKDIR /app
COPY --from=builder --chown=10001:10001 /src/app /app/app

USER 10001:10001
```

### Distroless Built-in Non-Root:
Distroless images provide a pre-configured unprivileged user named `nonroot` (UID 65532, GID 65532):
```dockerfile
FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=builder --chown=nonroot:nonroot /src/bin /app/bin
USER nonroot:nonroot
```

### Anti-Pattern: Post-Copy Recursive Chown
```dockerfile
# ❌ Anti-pattern: duplicates filesystem layer, ballooning image size
COPY . /app
RUN chown -R appuser:appgroup /app
```
**Fix**: Always use `COPY --chown=10001:10001 . /app`.

---

## 2. PID 1, Zombie Reaping & Signal Propagation

In Unix systems, the process with **PID 1** has two unique roles:
1. **Adopting and reaping zombie processes**: When orphaned child processes terminate, PID 1 must wait on them to release kernel process table entries.
2. **Handling signals**: Unlike standard processes, PID 1 does not receive default signal actions from the kernel. If a process does not explicitly install a signal handler for `SIGTERM`, the signal is silently discarded.

### Exec Form vs. Shell Form

#### ❌ Shell Form (Broken Signal Forwarding)
```dockerfile
# Runs: /bin/sh -c "node server.js"
CMD node server.js
```
The shell process becomes PID 1. `/bin/sh` does **not** forward `SIGTERM` to the child `node` process. When Docker issues `docker stop` (`SIGTERM`), the node server never receives the signal, fails to gracefully drain connections, and is forcibly murdered with `SIGKILL` after the 10-second timeout.

#### ✅ Exec Form (Correct)
```dockerfile
# Runs: node server.js directly as PID 1
ENTRYPOINT ["node", "server.js"]
```

### The `STOPSIGNAL` Instruction
By default, Docker sends `SIGTERM` on `docker stop`. Some applications expect different signals to initiate graceful connection draining:

- **Nginx**: Requires `SIGQUIT` for graceful stop (terminates active workers only after pending HTTP connections complete). With default `SIGTERM`, Nginx drops connections immediately!
- **Redis / PostgreSQL / Celery**: May require specific stop signals depending on supervisor scripts.

```dockerfile
# Mandate graceful stop signal in Dockerfile
STOPSIGNAL SIGQUIT
ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

### When to Use an Init System (`tini` / `dumb-init`)
Runtimes such as Node.js, Python, or Ruby do not natively reap orphaned child processes. If your application spawns subprocesses (e.g. background workers, headless browsers), use `tini` as the init supervisor:

```dockerfile
# Alpine example with tini
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
```
Or in Compose:
```yaml
services:
  app:
    image: my-app:latest
    init: true  # Automatically injects tini as PID 1
```

---

## 3. Read-Only Root Filesystems

Making the root filesystem immutable prevents attackers or compromised code from installing malware, altering configuration, or executing scripts from temporary directories.

### In Dockerfile:
Ensure the application writes ephemeral data only to explicit directories (such as `/tmp` or `/app/logs`):
```dockerfile
# If application needs a temporary write cache:
VOLUME ["/tmp"]
```

### In Docker Compose / CLI:
```yaml
services:
  api:
    image: my-api:1.0.0
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m
      - /run:rw,noexec,nosuid,size=16m
```

---

## 4. Modern `HEALTHCHECK` Instructions

A Docker health check allows the Docker daemon and orchestrators (Compose, Swarm, Kubernetes) to determine whether the service inside the container is functioning properly, not merely whether its process is alive.

### Syntax & Parameters
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/app/healthcheck.sh"]
```

- `--interval`: Duration between checks (default: `30s`).
- `--timeout`: Duration before the check is marked failed (default: `30s`).
- `--start-period`: Grace period for initialization where failures do not count toward retries (default: `0s`).
- `--retries`: Consecutive failures required to transition status to `unhealthy` (default: `3`).

### Curl-Free Health Check Recipes (Minimal Images):

When `curl` or `wget` is absent from minimal Distroless, Chainguard, or Alpine containers:

| Runtime / Base | Native Health Check Command |
| :--- | :--- |
| **Alpine (wget)** | `CMD ["wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:8080/health"]` |
| **Node.js** | `CMD ["node", "-e", "require('http').get('http://127.0.0.1:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"]` |
| **Python** | `CMD ["python3", "-c", "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').getcode() == 200 else 1)"]` |
| **Go (Compiled Probe)** | Pre-compiled static binary: `CMD ["/app/healthcheck"]` |

#### Go Native Health Check Binary Example:
```go
// healthcheck.go
package main
import (
    "net/http"
    "os"
)
func main() {
    resp, err := http.Get("http://127.0.0.1:8080/healthz")
    if err != nil || resp.StatusCode != http.StatusOK {
        os.Exit(1)
    }
    os.Exit(0)
}
```
In multi-stage builder:
```dockerfile
RUN CGO_ENABLED=0 go build -o /out/healthcheck ./cmd/healthcheck
# In runner:
COPY --from=builder /out/healthcheck /app/healthcheck
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD ["/app/healthcheck"]
```
