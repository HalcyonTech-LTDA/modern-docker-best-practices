# syntax=docker/dockerfile:1
# =============================================================================
# Production Multi-Stage Dockerfile for Spring Boot 3.x+ / Java 21+ Microservices
# Features: Gradle cache mounts, Spring Boot layered jar extraction (jarmode=tools),
#           Temurin JRE Alpine runner, non-root user, JVM container memory limits
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build Application and Extract Layers
# -----------------------------------------------------------------------------
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /workspace

# Cache Gradle wrapper and dependencies
COPY gradlew gradlew.bat settings.gradle.kts build.gradle.kts ./
COPY gradle/ gradle/
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    ./gradlew dependencies --no-daemon

# Compile and package application jar
COPY src/ src/
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    ./gradlew bootJar --no-daemon -x test

# Extract layers into separate directory using modern Spring Boot tools
RUN java -Djarmode=tools -jar build/libs/*.jar extract --layers --destination extracted/

# -----------------------------------------------------------------------------
# Stage 2: Hardened Runtime Container
# -----------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine AS runner
WORKDIR /app

# Provision unprivileged system user
RUN addgroup -g 10001 -S appgroup \
    && adduser -u 10001 -S appuser -G appgroup

# Copy layers separately: unchanged third-party libraries remain cached!
COPY --from=builder --chown=10001:10001 /workspace/extracted/dependencies/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=10001:10001 /workspace/extracted/application/ ./

USER 10001:10001
EXPOSE 8080

# Configure JVM container cgroup awareness and heap sizing
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Use JarLauncher for fast, classpath-based launch
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
