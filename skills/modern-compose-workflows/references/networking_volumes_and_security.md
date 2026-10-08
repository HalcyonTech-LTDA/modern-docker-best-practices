# Network Segmentation, Volumes & Security Hardening

Docker Compose provides robust primitives to isolate services, secure container filesystems, and protect host resources from compromise or exhaustion.

---

## 1. Network Architecture & Segmentation

By default, Docker Compose places all services into a single shared network where every service can communicate with every other service. In production-like or secure staging topologies, you must segment networks by trust boundaries.

### Multi-Tier Segmentation with `internal: true`

```yaml
services:
  # Public reverse proxy / gateway
  gateway:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
      - "443:443"
    networks:
      - public_net

  # Application backend
  api:
    image: my-api:latest
    networks:
      - public_net
      - data_net

  # Database: Completely isolated from public ingress and internet egress
  database:
    image: postgres:16-alpine
    networks:
      - data_net
    # Note: No 'ports' mapping! Accessible ONLY by members of data_net

networks:
  public_net:
    driver: bridge
  data_net:
    driver: bridge
    internal: true # No gateway configured; completely cuts off external internet routing
```

### Port Binding Discipline
When exposing ports on developer workstations:
```yaml
# ❌ Dangerous: Listens on all host interfaces (0.0.0.0), exposing service to local LAN/Wi-Fi
ports:
  - "5432:5432"

# ✅ Secure: Listens strictly on localhost loopback interface
ports:
  - "127.0.0.1:5432:5432"
```

---

## 2. Storage & Volume Strategy

### Named Volumes vs. Bind Mounts

| Storage Type | Syntax | Best Used For | Security Recommendation |
| :--- | :--- | :--- | :--- |
| **Named Volume** | `postgres_data:/var/lib/postgresql/data` | Database files, persistent state | Managed by Docker; survives container recreate; inspect with `docker volume inspect`. |
| **Bind Mount** | `./config/nginx.conf:/etc/nginx/nginx.conf:ro` | Configuration files, local source code | Always add `:ro` (read-only) unless write access is strictly required. |

### Securing Bind Mounts
```yaml
services:
  web:
    image: nginx:alpine
    volumes:
      # Read-only configuration mount prevents runtime tampering
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
```

---

## 3. Container Security Hardening

Apply the principle of least privilege directly in Compose service definitions:

```yaml
services:
  backend:
    image: my-backend:1.0.0
    # 1. Enforce non-root execution
    user: "10001:10001"

    # 2. Immutable root filesystem
    read_only: true

    # 3. Provide temporary write paths with strict execution flags
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m
      - /run:rw,noexec,nosuid,size=16m

    # 4. Prevent privilege escalation
    security_opt:
      - no-new-privileges:true

    # 5. Drop all default Linux capabilities
    cap_drop:
      - ALL

    # 6. Enable init supervisor for signal handling and zombie reaping
    init: true

    # 7. Restart policy
    restart: unless-stopped
```

---

## 4. Resource Allocation & Limits

Without resource boundaries, a memory leak or CPU spike in a single container can crash the host kernel (OOM panic) and take down all co-located services.

```yaml
services:
  api:
    image: my-api:latest
    deploy:
      resources:
        limits:
          cpus: "2.0"       # Maximum 2 CPU cores
          memory: 1024M     # Hard memory ceiling; triggers OOM inside container, not host
        reservations:
          cpus: "0.25"      # Guaranteed CPU allocation
          memory: 256M      # Guaranteed memory allocation
```
*(Note: Compose applies `deploy.resources.limits` natively in Docker Compose v2 even without Swarm mode).*

---

## 5. Graceful Termination & Stop Grace Periods (`stop_grace_period`)

When stopping services (`docker compose down` or `docker compose stop`), Docker sends `SIGTERM` to the container process. By default, Docker waits only **10 seconds** before forcibly killing the container with `SIGKILL`.

For stateful databases (PostgreSQL, MySQL), message queues (RabbitMQ), or web services draining active HTTP connections, 10 seconds is often insufficient, risking data corruption, partial transactions, or 502 errors.

Declare `stop_grace_period` to give services adequate shutdown time:

```yaml
services:
  db:
    image: postgres:16-alpine
    stop_grace_period: 30s # Allows Postgres to complete checkpoints and flush buffers

  api:
    image: my-api:latest
    stop_grace_period: 20s # Allows HTTP server to drain in-flight requests gracefully
```
