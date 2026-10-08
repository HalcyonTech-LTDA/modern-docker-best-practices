# syntax=docker/dockerfile:1
# =============================================================================
# Production Hardened Multi-Stage Dockerfile for Go Microservices
# Features: Fast cross-compilation (--platform=$BUILDPLATFORM), static linking,
#           module caching, minimal Distroless static runtime, non-root user
# =============================================================================

FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder
WORKDIR /src

ARG TARGETOS
ARG TARGETARCH

# Download modules with cache mounts
RUN --mount=type=bind,source=go.mod,target=go.mod \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

COPY . .

# Compile static binary with optimizations and symbol stripping
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/server

# -----------------------------------------------------------------------------
# Runtime: Completely static Distroless container (zero shell, nonroot)
# -----------------------------------------------------------------------------
FROM gcr.io/distroless/static-debian12:nonroot AS runner
WORKDIR /app

COPY --from=builder --chown=nonroot:nonroot /out/app /app/server

USER nonroot:nonroot
EXPOSE 8080

ENTRYPOINT ["/app/server"]
