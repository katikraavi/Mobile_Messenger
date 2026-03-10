# Quickstart: Initialize Flutter Messenger Project

**Last Updated**: March 10, 2026  
**Audience**: New developers, project maintainers  
**Time Needed**: 15-20 minutes

## Prerequisites

Before starting, ensure you have the following installed:

- **Git**: `git --version` (any recent version)
- **Docker Desktop**: `docker --version` and `docker-compose --version` (Docker Compose v2.0+)
- **Flutter SDK**: `flutter --version` (3.10.0+)
- **Android SDK or Xcode**: For mobile emulation
  - Android: Android Studio with configured emulator
  - iOS: Xcode + iOS Simulator (macOS only)
- **Code Editor**: VS Code, Android Studio, or similar IDE with Dart/Flutter extension

## Quick Start (5-10 minutes)

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/mobile-messenger.git
cd mobile-messenger
```

### 2. Configure Environment (If This Is First Run)

The project includes configuration templates. On first run, Docker Compose uses the default environment:

- **Root template**: `/.env.example` — Template reference (do not edit directly)
- **Actual backend config**: `/backend/.env` — Used by Docker Compose to connect backend to PostgreSQL

If `/backend/.env` doesn't exist, Docker Compose will use environment variables defined in `docker-compose.yml`. For custom configuration:

```bash
# Copy the template (if you need to customize)
cp .env.example /backend/.env

# Edit with your custom DATABASE_URL, SERVERPOD_ENV, SERVERPOD_PORT if needed
# Default values in docker-compose.yml work for local development
```

### 3. Start the Backend & Database

```bash
docker-compose up
```

**Expected Output** (wait 30-60 seconds):
```
postgres_1   | database system is ready to accept connections
serverpod_1  | Serverpod started on port 8081
serverpod_1  | [INFO] Health check endpoint available at http://localhost:8081/health
```

**Troubleshooting**:
- `Port 5432 already in use`: Another PostgreSQL is running. Edit `docker-compose.yml` port mapping or stop the conflicting service.
- `Port 8081 already in use`: Another Serverpod is running. Edit `docker-compose.yml` port mapping.
- `docker: command not found`: Install Docker Desktop (https://www.docker.com/products/docker-desktop)
- `.env` issues: Ensure `/backend/.env` is readable by Docker or use default values from `docker-compose.yml`

### 4. Verify Backend Health (in another terminal)

```bash
# Check health endpoint
curl http://localhost:8081/health

# Expected response (pretty-printed):
# {
#   "status": "ok",
#   "timestamp": "2026-03-10T14:30:45.123456Z",
#   "uptime_ms": 45678
# }
```

### 5. Start Flutter App Development

```bash
# In another terminal, navigate to frontend
cd frontend
flutter pub get
flutter run
```

**Device Selection** (Flutter will prompt):
- Choose Android Emulator or iOS Simulator
- If a device is running, Flutter will deploy to it

**Expected Output**:
```
Running Dart obfuscation on app bundle...
App is now connected to the Dart server. Frame times (time spent rendering frames) are:
...
I/flutter ( 1234): App connected to backend at http://host.docker.internal:8081
```

**Visual Check**:
- App should launch without immediate errors
- Loading screen should appear briefly
- Connection should establish (verify in backend logs: `[INFO] Client connected from 172.0.0.1`)

## Detailed Breakdown

### Backend Structure

```text
backend/                          # Serverpod backend
├── lib/
│   ├── server.dart               # Main server entry point
│   └── src/
│       ├── endpoints/
│       │   └── health.dart       # Health check endpoint
│       ├── services/             # Business logic (to be populated)
│       └── models/               # Data models (to be populated)
├── config/                       # Configuration files
├── migrations/                   # Auto-generated database migrations
├── pubspec.yaml                  # Dart dependencies
└── Dockerfile                    # Container build (see docker-compose.yml)
```

**Key File: `backend/lib/server.dart`**

This file initializes the Serverpod server, connects to PostgreSQL, and registers endpoints:

```dart
import 'package:serverpod/serverpod.dart';
import 'src/endpoints/health.dart';
import 'src/services/user_service.dart';

void main(List<String> args) async {
  // Initialize server with database connection
  final server = Server(
    Protocol(),
    addresses: [InternetAddress.anyIPv4],
    port: 8081,
  );

  // Register endpoints
  server.webSocketRouter.defaultHandler = HealthEndpoint().handler;
  
  // Run database migrations
  await server.runMigrations();
  
  await server.start();
}
```

### Frontend Structure

```text
frontend/                         # Flutter mobile app
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # Root widget and routing
│   ├── core/
│   │   ├── models/               # Shared data models
│   │   ├── services/
│   │   │   └── api_client.dart   # Backend HTTP/WebSocket client
│   │   ├── utils/                # Constants, helpers
│   │   └── widgets/              # Reusable UI widgets
│   └── features/                 # Feature modules
│       ├── auth/
│       ├── profile/
│       ├── chat/
│       └── invites/
├── test/                         # Unit and widget tests
├── pubspec.yaml                  # Flutter dependencies
└── (ios/, android/ auto-generated)
```

**Key File: `frontend/lib/main.dart`**

This file initializes the Flutter app and connects to the backend:

```dart
import 'package:flutter/material.dart';
import 'core/services/api_client.dart';
import 'app.dart';

void main() async {
  // Initialize API client with backend URL
  await ApiClient.initialize(
    baseUrl: 'http://host.docker.internal:8081',  // For Android emulator
  );
  
  runApp(const MessengerApp());
}
```

### Docker Compose Configuration

**File: `docker-compose.yml`** (at repository root)

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:13-alpine
    environment:
      POSTGRES_USER: messenger_user
      POSTGRES_PASSWORD: messenger_password
      POSTGRES_DB: messenger_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U messenger_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  serverpod:
    build: ./backend
    ports:
      - "8081:8081"
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://messenger_user:messenger_password@postgres:5432/messenger_db
      SERVERPOD_ENV: development
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/health"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s

volumes:
  postgres_data:
```

**Key Points**:
- `depends_on`: Ensures PostgreSQL starts before Serverpod
- `healthcheck`: Docker monitors if services remain healthy
- `postgres_data` volume: Persists database across restarts
- `DATABASE_URL` env: Backend uses this to connect to PostgreSQL

## Common Tasks

### Stop All Services

```bash
# Stop backend and database (keep containers)
docker-compose stop

# Stop and remove containers (data persists in volume)
docker-compose down

# Stop, remove containers AND delete database
docker-compose down -v  # Warning: deletes postgres_data volume
```

### View Backend Logs

```bash
# All services
docker-compose logs

# Only Serverpod backend
docker-compose logs serverpod

# Follow logs in real-time
docker-compose logs -f serverpod

# Last 50 lines
docker-compose logs --tail 50

# Logs from specific time
docker-compose logs --since 2026-03-10T14:00:00
```

### Restart Backend

```bash
# Restart without stopping database (preserves data)
docker-compose restart serverpod

# Or, stop and start
docker-compose stop serverpod
docker-compose start serverpod
```

### Access PostgreSQL Directly

```bash
# Connect to database via Docker
docker-compose exec postgres psql -U messenger_user -d messenger_db

# Within psql:
# \dt              - List all tables
# SELECT * FROM users;  - Query users table
# \q              - Exit
```

### Reset Database (dev use only)

```bash
# Remove data volume and restart
docker-compose down -v
docker-compose up
# Wait 30-60 seconds for database initialization
```

### Check Container Status

```bash
# List running containers
docker-compose ps

# Inspect logs for issues
docker-compose logs --tail 100

# View resource usage
docker stats
```

## Testing the Setup

### Verify Backend is Responsive

```bash
# Health check
curl http://localhost:8081/health

# Expected output:
# {"status":"ok","timestamp":"2026-03-10T14:30:45.123456Z","uptime_ms":45678}
```

### Verify Database is Accessible

```bash
# List databases
docker-compose exec postgres psql -U messenger_user -l

# Verify tables were created
docker-compose exec postgres psql -U messenger_user -d messenger_db -c '\dt'
```

### Verify Flutter Can Connect

1. Launch Flutter app: `flutter run` (from `frontend/` directory)
2. Check app logs: Should see connection message like "Backend connected: http://host.docker.internal:8081"
3. Look for errors: If app can't connect, check backend logs: `docker-compose logs serverpod`
4. Verify emulator networking:
   - Android: Use `host.docker.internal:8081`
   - iOS Simulator: Use `localhost:8081`
   - Physical device: Use `<host-machine-ip>:8081`

## Directory Reference

| Path | Purpose |
|------|---------|
| `/backend` | Serverpod server code, endpoints, services, models |
| `/frontend` | Flutter app code, features, widgets, services |
| `/docker-compose.yml` | Container orchestration |
| `/.gitignore` | Git ignore rules |
| `/README.md` | Project-level documentation |
| `/specs/001-messenger-init/` | Feature specification, plan, design artifacts |

## Next Steps

1. ✅ Backend and database running via `docker-compose up`
2. ✅ Flutter app launched and connected to backend
3. 📋 **Next**: Explore backend code in `backend/lib/src/endpoints/health.dart`
4. 📋 **Next**: Explore frontend code in `frontend/lib/main.dart`
5. 📋 **Next**: Run tests: `cd frontend && flutter test`
6. 📋 **Next**: Create your first endpoint (auth feature, coming next)

## Troubleshooting

### Problem: "Cannot connect to Docker daemon"

**Solution**: Start Docker Desktop or Docker service

```bash
# macOS / Windows
open /Applications/Docker.app

# Linux
sudo systemctl start docker
```

### Problem: "Port 5432 already in use"

**Solution**: Either stop the conflicting service or use a different port

```bash
# Option 1: Change port in docker-compose.yml
# Change "5432:5432" to "5433:5432"

# Option 2: Kill existing PostgreSQL
lsof -i :5432 | grep LISTEN
kill -9 <PID>
```

### Problem: "Flutter cannot find Android emulator"

**Solution**: Ensure emulator is running

```bash
# List available emulators
flutter emulators

# Start emulator
flutter emulators --launch <emulator_name>

# Then run app
flutter run
```

### Problem: "Backend returns 503 or connection refused"

**Solution**: Wait longer for startup, check health endpoint

```bash
# Health check
curl http://localhost:8081/health
# Returns 503? Serverpod still initializing. Wait 10-15 seconds.

# Check logs
docker-compose logs serverpod | tail -50

# Common reason: Database not ready. Check:
docker-compose logs postgres | tail -50
```

### Problem: "Flutter app keeps retrying connection"

**Cause**: Backend unhealthy or unreachable
**Solution**:
1. Verify backend is running: `docker-compose ps`
2. Verify health endpoint: `curl http://localhost:8081/health`
3. Check Docker logs: `docker-compose logs -f`
4. Restart services: `docker-compose restart`
5. Use correct URL for your platform (Android uses `host.docker.internal`, iOS uses `localhost`)

## Support & Questions

For issues or questions:
1. Check Docker logs: `docker-compose logs`
2. Verify all prerequisites installed: `git`, `docker`, `flutter`
3. Consult specification: `spec.md`
4. Review detailed plan: `plan.md`

## Next Feature: User Authentication

After verifying this setup works, proceed to the next feature (e.g., `002-user-authentication`) which will implement:
- User registration & login endpoints
- JWT token generation
- User model and database table
- Auth middleware for protecting endpoints
