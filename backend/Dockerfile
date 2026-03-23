# Build stage
FROM dart:3.5 AS builder

WORKDIR /build

# Copy pubspec files
COPY pubspec.yaml pubspec.yaml
COPY pubspec.lock pubspec.lock

# Get dependencies
RUN dart pub get

# Copy source code
COPY . .

# Runtime stage
FROM dart:3.5

WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy pubspec files
COPY --from=builder /build/pubspec.yaml /app/pubspec.yaml
COPY --from=builder /build/pubspec.lock /app/pubspec.lock

# Get dependencies in runtime container
RUN dart pub get

# Copy source code
COPY --from=builder /build/lib /app/lib
COPY --from=builder /build/config /app/config

# Expose port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD curl -f http://localhost:8081/health || exit 1

# Run the application
CMD ["dart", "run", "lib/server.dart"]
