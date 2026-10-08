# Production Dockerfile Hardening & Audit Checklist

Use this checklist during code review or pipeline security auditing to verify container quality, performance, and least-privilege compliance.

---

## 1. Syntax & Engine Directives
- [ ] `# syntax=docker/dockerfile:1` is the very first line of the Dockerfile.
- [ ] Multi-stage architecture decouples build tools (JDK, Go compiler, Python build-essential, npm) from shipping runtime stages.
- [ ] All intermediate build stages have explicit, meaningful names (`AS deps`, `AS builder`, `AS runner`).

## 2. Base Image Hygiene & Supply Chain Security
- [ ] Base images are pinned to explicit semantic versions with OS tags (`node:22.12.0-alpine3.20`) or immutable SHA256 digests (`@sha256:...`).
- [ ] Mutable tags (`:latest`, `:alpine`, `:bookworm`, `:3`) are prohibited.
- [ ] Minimal runtime base images are prioritized (Google Distroless, Chainguard, Alpine, Debian Slim).
- [ ] Package manager cache cleanup is implemented where applicable (`rm -rf /var/lib/apt/lists/*` on Debian/Ubuntu).

## 3. Least-Privilege & Non-Root Execution
- [ ] Production containers do NOT run as `root` (UID 0).
- [ ] An explicit non-root user/group is created or selected (`USER nonroot:nonroot` or `USER 10001:10001`).
- [ ] Files copied to runner stages use `--chown=<user>:<group>` on the `COPY` instruction to prevent duplicate layer creation.
- [ ] No recursive `RUN chown -R` commands follow large file copy instructions.

## 4. Cache Efficiency & BuildKit Mounts
- [ ] Dependency manifests (`package.json`, `go.mod`, `pom.xml`, `pyproject.toml`) are copied and installed BEFORE source code is copied.
- [ ] Package managers use BuildKit cache mounts (`--mount=type=cache,target=...`) to prevent re-downloading across builds.
- [ ] Ephemeral build files utilize read-only context bind mounts (`--mount=type=bind`) instead of persistent `COPY` layers where appropriate.
- [ ] Multi-architecture builds use `--platform=$BUILDPLATFORM` for native compiler speed, cross-compiling to `$TARGETARCH`.

## 5. Secret Protection
- [ ] Zero build tokens, API keys, private SSH keys, or cloud credentials exist in `ENV` or `ARG` instructions.
- [ ] Build-time credentials use BuildKit secret mounts (`RUN --mount=type=secret,id=...`).
- [ ] Git commit SHA and version metadata are passed via `--build-arg COMMIT_SHA=...`, NEVER by copying `.git/` into the image.

## 6. Process Lifecycle & POSIX Signals
- [ ] `ENTRYPOINT` and `CMD` strictly use exec JSON array syntax (`ENTRYPOINT ["executable", "arg1"]`).
- [ ] Shell form (`CMD npm start` or `ENTRYPOINT /bin/sh -c ...`) is strictly avoided.
- [ ] If application does not natively reap zombie processes, `tini` or `dumb-init` is configured.
- [ ] `STOPSIGNAL` is explicitly declared if the service requires a signal other than `SIGTERM` (e.g., `STOPSIGNAL SIGQUIT` for Nginx).

## 7. Container Healthcheck
- [ ] Appropriate `HEALTHCHECK` instruction is defined with `--interval`, `--timeout`, `--start-period`, and `--retries`.
- [ ] Probes in minimal or Distroless containers avoid unavailable utilities (e.g. `curl`) in favor of native runtime probes (`wget` on Alpine, Node/Python HTTP one-liners, or compiled binaries).
