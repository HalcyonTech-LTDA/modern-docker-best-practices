# syntax=docker/dockerfile:1
# =============================================================================
# Production Hardened Multi-Stage Dockerfile for Node.js & TypeScript
# Features: BuildKit cache mounts, bind mounts, Distroless runtime, non-root user
# =============================================================================

ARG NODE_VERSION=22.12.0
ARG ALPINE_VERSION=3.20

# -----------------------------------------------------------------------------
# Stage 1: Dependency Resolution
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS deps
WORKDIR /usr/src/app

# Fast package installation utilizing BuildKit cache and bind mounts
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --include=dev

# -----------------------------------------------------------------------------
# Stage 2: Compilation & Pruning
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS builder
WORKDIR /usr/src/app
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .

# Compile TypeScript and remove development dependencies
RUN npm run build \
    && npm prune --omit=dev

# -----------------------------------------------------------------------------
# Stage 3: Minimal Production Runner (Distroless)
# -----------------------------------------------------------------------------
FROM gcr.io/distroless/nodejs22-debian12:nonroot AS runner
WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000

# Copy only production dependencies, compiled artifacts, and manifest
COPY --from=builder --chown=nonroot:nonroot /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /usr/src/app/dist ./dist
COPY --from=builder --chown=nonroot:nonroot /usr/src/app/package.json ./package.json

USER nonroot:nonroot
EXPOSE 3000

ENTRYPOINT ["/nodejs/bin/node", "dist/main.js"]
