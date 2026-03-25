# Build stage
FROM dart:3.5 AS builder

WORKDIR /build

# Copy backend pubspec files
COPY backend/pubspec.yaml backend/pubspec.yaml
COPY backend/pubspec.lock backend/pubspec.lock

# Get dependencies
RUN cd backend && dart pub get

# Copy source code
COPY backend/ backend/

# Runtime stage
FROM dart:3.5

WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy pubspec files
COPY --from=builder /build/backend/pubspec.yaml /app/pubspec.yaml
COPY --from=builder /build/backend/pubspec.lock /app/pubspec.lock

# Get dependencies in runtime container
RUN dart pub get

# Copy source code
COPY --from=builder /build/backend/lib /app/lib

# Ensure expected runtime directories exist even when source folders are empty.
RUN mkdir -p /app/config /app/uploads

# Expose port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD curl -f http://localhost:8081/health || exit 1

# Run the application
CMD ["dart", "run", "lib/server.dart"]
