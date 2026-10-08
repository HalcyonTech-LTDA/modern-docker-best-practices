# Docker Compose Healthcheck Cheatsheet

Reference implementations for common backing services. When using `CMD-SHELL`, always remember to escape environment variables with `$$` so that Compose does not evaluate them on the host machine.

---

## 1. Relational Databases

### PostgreSQL
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-postgres}"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 10s
```

### MySQL 8.x+
```yaml
healthcheck:
  test: ["CMD-SHELL", "mysqladmin ping -h localhost -u root --silent || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 20s
```

### MariaDB
```yaml
healthcheck:
  test: ["CMD-SHELL", "mariadb-admin ping -h localhost -u root --silent || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 20s
```

---

## 2. In-Memory & NoSQL Datastores

### Redis
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
```
*(With password)*:
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "-a", "$${REDIS_PASSWORD}", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
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

---

## 3. Message Brokers & Streaming

### RabbitMQ
```yaml
healthcheck:
  test: ["CMD", "rabbitmq-diagnostics", "-q", "check_running"]
  interval: 15s
  timeout: 10s
  retries: 5
  start_period: 20s
```

### Redpanda (Kafka Compatible)
```yaml
healthcheck:
  test: ["CMD-SHELL", "rpk cluster health | grep -q 'Healthy:.*true'"]
  interval: 15s
  timeout: 5s
  retries: 5
  start_period: 15s
```

---

## 4. Search & Analytics

### Elasticsearch
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -s -f http://localhost:9200/_cluster/health?local=true || exit 1"]
  interval: 20s
  timeout: 10s
  retries: 5
  start_period: 30s
```

---

## 5. Web & API Probes

### Alpine Linux Container (wget)
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1"]
  interval: 15s
  timeout: 3s
  retries: 3
  start_period: 10s
```

### Debian/Ubuntu Container (curl)
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://127.0.0.1:8080/health || exit 1"]
  interval: 15s
  timeout: 3s
  retries: 3
  start_period: 10s
```

### Node.js (Minimal / Distroless)
```yaml
healthcheck:
  test: ["CMD", "node", "-e", "require('http').get('http://127.0.0.1:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"]
  interval: 15s
  timeout: 3s
  retries: 3
  start_period: 5s
```
