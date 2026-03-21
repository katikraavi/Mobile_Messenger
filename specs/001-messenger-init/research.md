# Research: Initialize Flutter Messenger Project

**Created**: March 10, 2026  
**Phase**: 0 - Research & Technology Selection  
**Input**: Clarified specification with all decisions confirmed

## Executive Summary

All key technology and architectural decisions have been confirmed during specification clarification. No outstanding NEEDS CLARIFICATION markers remain. This document consolidates the rationale, alternatives considered, and implementation guidance for the chosen tech stack.

## Technology Stack Selection

### Language & Framework: Dart + Flutter + Serverpod

**Decision**: Unified Dart ecosystem for both frontend (Flutter) and backend (Serverpod)

**Rationale**:
- **Code Sharing**: Shared data models and utility functions between frontend/backend reduce duplication
- **Development Velocity**: Single language means developers can work on both frontend and backend without context switching
- **Hot Reload**: Flutter's hot reload + Serverpod's capabilities enable rapid iteration during development
- **Type Safety**: Dart's strong typing catches errors at compile-time
- **Community**: Rapidly growing Dart ecosystem with excellent Flutter and Serverpod support

**Alternatives Considered**:
1. **Node.js backend + Flutter frontend**: Would require two languages; popular but introduces complexity
   - Rejected: Requires maintaining two runtimes; data model translation overhead
2. **Kotlin backend + Flutter frontend**: Android-native backend strategy
   - Rejected: Doesn't leverage Dart ecosystem; forces Java/JVM runtime on backend
3. **Go backend + Flutter frontend**: Lightweight Go backend with mobile frontend
   - Rejected: Language mismatch; Go lacks built-in mobile client libraries; learning curve

### Database: PostgreSQL 13+

**Decision**: PostgreSQL as primary relational database with Serverpod ORM integration

**Rationale**:
- **Serverpod Native**: Serverpod includes built-in PostgreSQL ORM and migration tooling
- **Maturity**: PostgreSQL is battle-tested, production-ready, excellent documentation
- **Docker-Friendly**: Official Docker image, easy to run in containers with volume persistence
- **JSON Support**: Native JSONB type valuable for storing complex data (e.g., encrypted metadata)
- **Open Source**: No licensing costs, vendor-neutral

**Alternatives Considered**:
1. **SQLite**: Lightweight, but not suitable for server-side multi-user applications
   - Rejected: Limited concurrent access; not designed for server workloads; no networking layer
2. **MySQL 8.0**: Popular, but less feature-rich than PostgreSQL
   - Rejected: PostgreSQL has better JSON support, superior ACID guarantees; Serverpod optimized for PostgreSQL
3. **MongoDB**: NoSQL document database
   - Rejected: Unnecessary complexity for this feature; loses relational benefits; less ideal for ACID transactions

### Containerization: Docker Compose (Local), Docker (Production)

**Decision**: Docker Compose for local development; Docker Compose template for production deployment

**Rationale**:
- **Development Parity**: Local environment matches deployment environment (eliminate "works on my machine" issues)
- **Single Command**: `docker-compose up` starts all services—enables 15-minute onboarding
- **Service Orchestration**: Automatic networking, port mapping, health checks, restart policies
- **Volume Persistence**: PostgreSQL data survives container restarts via named volumes
- **Environment Configuration**: env files for managing API endpoints, ports, credentials across environments

**Alternatives Considered**:
1. **Kubernetes**: Industry standard, but overkill for local development
   - Rejected: Steep learning curve; unnecessarily complex for single-backend setup; minikube adds overhead
2. **Manual Docker** (no Compose): Better control, but manual orchestration
   - Rejected: Developers must remember docker run commands; no declarative infrastructure; harder to version control
3. **Local Dev Servers** (no containers): Simplest but defeats purpose
   - Rejected: Environment mismatch; setup burden on developers; reproducibility issues

### Architecture: Monorepo with Separate Frontend/Backend

**Decision**: Single Git repository with `/frontend` and `/backend` directories

**Rationale**:
- **Shared Utilities**: Models, constants, enums can be shared via Dart packages
- **Simplified Workflow**: Single clone, single build process, unified versioning
- **Independent Scaling**: Frontend and backend can evolve independently despite sharing repo
- **Clear Ownership**: `/frontend` and `/backend` provide natural team boundaries
- **Atomic Commits**: Features spanning frontend/backend captured in single commit

**Alternatives Considered**:
1. **Multi-repo** (separate repositories for frontend/backend):
   - Rejected: Synchronization overhead; version mismatch issues; separate PRs for single feature; deployment choreography complexity
2. **Nested Projects** (Frontend/Backend under shared `/app` directory):
   - Rejected: Less clear separation of concerns; harder to set different ownership policies; ambiguous top-level imports

### Architecture Layers: Three-Tier (Frontend → Backend → Database)

**Decision**: Flutter client → Serverpod backend → PostgreSQL database

**Rationale**:
- **Separation of Concerns**: Clear responsibilities for each layer
- **Scalability**: Backend can scale independently; database can be replaced/upgraded
- **Security Boundary**: Frontend is untrusted (user-controlled); backend enforces business logic and data security
- **WebSocket Support**: Serverpod's built-in WebSocket support enables real-time messaging for chat features

**Layer Responsibilities**:
1. **Frontend (Flutter)**:
   - UI/UX rendering, user interactions
   - Local caching, offline support preparation
   - Automatic retry logic (exponential backoff) for resilience
   
2. **Backend (Serverpod)**:
   - Business logic validation, authorization
   - Encryption/decryption (per Constitution security requirements)
   - Database persistence, transaction management
   - Real-time WebSocket communication for chat
   
3. **Database (PostgreSQL)**:
   - Durable, ACID-compliant data storage
   - Relational integrity via foreign keys
   - Encrypted data at rest via Serverpod integration

## Implementation Guidance

### Docker Compose Configuration

**postgres Service**:
- Image: `postgres:13-alpine` (lightweight, security-focused)
- Environment: `POSTGRES_PASSWORD`, `POSTGRES_DB` set from `.env`
- Volumes: Named volume `postgres_data` persists data across restarts
- Health check: `pg_isready` ensures readiness before Serverpod starts
- Port: 5432 (internal), accessible as `postgres:5432` from Serverpod via service name

**serverpod Service**:
- Image: Built from `backend/Dockerfile` (to be created in implementation)
- Build context: `./backend`
- Environment variables: `DATABASE_URL=postgres://user:password@postgres:5432/dbname`
- Depends on: `postgres` service (ensures database starts first)
- Health check: `GET /health` endpoint (allows orchestration to verify readiness)
- Port: 8081 (standard Serverpod port)

**Network**: Default Docker Compose bridge network enables automatic service discovery by hostname

### Flutter Connection Strategy

**Endpoint Configuration**:
```dart
// Development (via docker-compose)
String backendUrl = 'http://host.docker.internal:8081';  // Android emulator
String backendUrl = 'http://localhost:8081';              // iOS simulator
String backendUrl = 'http://<device-ip>:8081';            // Physical device
```

**Retry Logic** (implemented in Flutter app):
```
Attempt 1: immediate
Attempt 2: wait 100ms
Attempt 3: wait 500ms
Attempt 4: wait 2000ms
Attempt 5: wait 5000ms
Attempt 6: wait 10000ms
After 6th failure: show user-friendly error "Backend unavailable"
```

**Health Check**:
- Endpoint: `GET /health`
- Response: `{"status": "ok", "timestamp": "2026-03-10T12:00:00Z", "uptime_ms": 12345}`
- Used by: Flutter app for startup verification; Docker orchestration for liveness checks

### Database Initialization

**Strategy**: Serverpod auto-handles schema migrations

1. **On startup**, Serverpod connects to PostgreSQL
2. **Serverpod checks** if migration table exists; if not, initializes it
3. **Serverpod applies** any pending migrations from `backend/migrations/` directory
4. **Models** in `backend/lib/src/models/` are source-of-truth for schema; Serverpod generates migrations

**Key Files** (to be created in implementation):
- `backend/migrations/1_initial_schema.sql` - Generated by Serverpod from models
- `backend/pubspec.yaml` - Specifies Serverpod version and migration settings

### Development Workflow

**Getting Started** (for new developer):
```bash
git clone <repo>
cd mobile-messenger
docker-compose up
# Wait 30-60 seconds for services to start
# In another terminal:
cd frontend
flutter run -d emulator
```

**Expected Output**:
- Docker containers running, visible via `docker ps`
- Backend logs showing: "Serverpod started on port 8081"
- PostgreSQL logs showing: "ready to accept connections"
- Flutter app connects and displays home screen with loading state initially
- On successful backend connection: app displays main UI

**Troubleshooting**:
- Ports already in use → modify `docker-compose.yml` port mappings
- Out of disk space → `docker system prune` to clean up volumes
- Database corruption → `docker volume rm mobile-messenger_postgres_data && docker-compose up`

## Dependencies & Versions

| Component | Version | Constraint | Reason |
|-----------|---------|-----------|--------|
| Flutter | 3.10.0+ | >= 3.10.0 | Dart 3.0+ required for modern syntax |
| Dart | 3.0.0+ | >= 3.0.0 | Null-safety, records, pattern matching |
| Serverpod | 2.1.0+ | >= 2.1.0 | Latest with PostgreSQL 13+ support |
| PostgreSQL | 13+ | >= 13 | Docker image availability, feature set |
| Docker | 20.10+ | >= 20.10 | Compose v2 support, buildkit features |
| Docker Compose | 2.0+ | >= 2.0 | Service health checks, depends_on conditions |

## Next Steps

1. **Phase 1 (Design)**: Generate data-model, contracts, and quickstart
2. **Phase 2 (Implementation)**: Create Dockerfiles, docker-compose.yml, project scaffolding
3. **Phase 3 (Verification)**: Test `docker-compose up`, verify health endpoint, test Flutter connection
