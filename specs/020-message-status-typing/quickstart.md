# Quick Start: Messaging Feature Development

**Date**: 2026-03-16  
**Scope**: Local development environment for messaging with status and typing indicators  
**Prerequisites**: Flutter, Dart, Docker, docker-compose

---

## Overview

This guide sets up the local development environment to work on the messaging feature. You'll be able to:
- Send/receive messages between two users
- See typing indicators in real-time
- Verify message status progression (sent → delivered → read)
- Test message edit and delete operations
- Run unit tests and UI tests

---

## Prerequisites

### System Requirements
- **OS**: Linux, macOS, or WSL2 on Windows
- **Disk Space**: ~5GB (Docker images, Flutter, dependencies)
- **RAM**: 4GB minimum, 8GB recommended

### Required Software
```bash
# Check versions
flutter --version       # Flutter 3.0+
dart --version         # Dart 2.19+
docker --version       # Docker 20.10+
docker-compose --version  # 1.29+
```

### Installation (if needed)
```bash
# Install Flutter: https://flutter.dev/docs/get-started/install
# Install Docker: https://docs.docker.com/get-docker/
# Install docker-compose: https://docs.docker.com/compose/install/
```

---

## Project Setup

### 1. Clone and Navigate
```bash
cd /path/to/mobile-messenger
git checkout 020-message-status-typing
```

### 2. Start Backend (Docker)
```bash
# Start PostgreSQL and Serverpod backend
docker-compose up --build -d

# Verify services are running
docker ps
# Should show: messenger-backend (healthy), messenger-postgres (healthy)

# Check backend logs
docker logs messenger-backend
# Should show: "🚀 Messenger Backend Started"
```

### 3. Verify Backend Connectivity
```bash
# Health check
curl http://localhost:8081/health
# Expected: {"status": "healthy", "timestamp": "..."}

# Check schema
curl http://localhost:8081/schema
# Confirms migrations ran
```

### 4. Configure Frontend
```bash
cd frontend

# Install dependencies
flutter pub get

# Set backend URL (optional, defaults to localhost:8081)
export API_BASE_URL=http://localhost:8081
```

### 5. Start Frontend (Linux Desktop or Emulator)
```bash
# For Linux desktop
flutter run -d linux

# For Android emulator (if available)
emulator -avd MyEmulator &
flutter run -d emulator-5554
```

---

## Local Testing Workflow

### Test 1: Send and Receive Messages (Two-User Flow)

**Terminal 1**: Start backend and first user
```bash
docker-compose up
# In another terminal
cd frontend && flutter run -d linux
# Login as alice@example.com / password
```

**Terminal 2**: Start second user on different device/emulator
```bash
# SSH to another machine, OR
# On same machine: Android emulator or different desktop session
flutter run -d emulator-5554
# Login as bob@example.com / password
```

**Flow**:
1. Alice opens a chat with Bob
2. Alice types: "Hello Bob!"
3. Verify in Alice's chat:
   - Message appears with "✓" (sent) status
   - Status changes to "✓✓" (delivered) within 2s
4. On Bob's device:
   - Message appears with "delivered" status
   - When Bob opens chat, status changes to "✓✓" (blue double-checkmark, read)
5. On Alice's device:
   - Confirm status changed to blue (read)

**Success Criteria**:
- Message appears on both devices
- Status progression: ✓ → ✓✓ → ✓✓ (blue)
- All transitions within 2 seconds

---

### Test 2: Typing Indicators

**Flow**:
1. Alice starts typing in message field
2. Observe Bob's chat:
   - After 100ms: "[Alice is typing...]" appears below messages
3. Alice keeps typing (keeps keystroke active)
   - Typing indicator remains visible
4. Alice stops typing (3s pause)
   - Typing indicator disappears after 3s
5. Bob types
   - Alice sees "[Bob is typing...]"

**Success Criteria**:
- Typing indicator appears within 1 second
- Stays visible while typing
- Disappears after 3 seconds of inactivity
- No duplicate indicators

---

### Test 3: Message Edit

**Flow**:
1. Alice sends: "Hello Bob!"
2. Within 30 seconds, Alice long-presses message
3. Select "Edit"
4. Change to: "Hello Bob! How are you?"
5. Tap "Confirm"
6. Verify:
   - Alice's message updates with "(edited)" label
   - Timestamp shows: "sent at 2:00pm, edited at 2:01pm"
   - Bob sees same message with "(edited)" label

**Success Criteria**:
- Edit appears on both devices
- "(edited)" indicator visible
- Timestamps show send and edit times

---

### Test 4: Message Delete

**Flow**:
1. Alice sends: "Oops, meant to send something else"
2. Within 30 seconds, Alice long-presses message
3. Select "Delete"
4. Confirm deletion
5. Verify:
   - Alice's chat shows "[message deleted]" placeholder
   - Bob's chat shows "[message deleted]" placeholder
   - Message content is not visible
   - Original sender/timestamp may still show

**Success Criteria**:
- Delete appears on both devices
- "[message deleted]" placeholder shown
- Message content hidden
- Both users see same placeholder

---

## Database Access

### View Messages Table
```bash
# Connect to PostgreSQL
docker exec -it messenger-postgres psql -U messenger_user -d messenger_db

# In psql shell
SELECT id, chat_id, sender_id, status, content FROM messages ORDER BY created_at DESC LIMIT 10;
SELECT * FROM message_status ORDER BY updated_at DESC LIMIT 10;
SELECT * FROM message_edits LIMIT 10;

# Count messages
SELECT COUNT(*) FROM messages;

# Exit
\q
```

### View Logs
```bash
# Backend logs (real-time)
docker logs -f messenger-backend

# Backend logs (last 100 lines)
docker logs --tail 100 messenger-backend

# Database logs
docker logs messenger-postgres
```

---

## Unit Testing

### Backend Message Service Tests
```bash
cd backend

# Run all message service tests
dart test test/unit/message_service_test.dart

# Run specific test
dart test test/unit/message_service_test.dart -n "should save message"

# Run with verbose output
dart test -v test/unit/message_service_test.dart
```

### Frontend Message Widget Tests
```bash
cd frontend

# Run all message tests
flutter test test/widget/message_bubble_test.dart

# Run with coverage
flutter test --coverage test/widget/message_bubble_test.dart

# View coverage report
genhtml coverage/lcov.info -o coverage/html
# Open coverage/html/index.html in browser
```

---

## Integration Testing

### Backend API Tests
```bash
cd backend

# Requires backend running (docker-compose up)
dart test test/integration/message_endpoints_test.dart

# Run specific integration test
dart test -n "send message flow" test/integration/message_endpoints_test.dart
```

### Frontend End-to-End Tests
```bash
cd frontend

# requires backend and emulator/simulator running
flutter test integration_test/messaging_test.dart

# Record test trace
flutter test --trace-startup integration_test/messaging_test.dart
```

---

## Common Issues & Troubleshooting

### Issue: "Connection refused" on localhost:8081

**Solution**:
```bash
# Check if backend is running
docker ps | grep messenger-backend

# If not running, start it
docker-compose up -d

# If running but not responding, check logs
docker logs messenger-backend

# Restart if stuck
docker-compose restart messenger-backend
```

### Issue: Flutter app can't connect to backend

**Solution**:
```bash
# On Linux desktop, backend and frontend on same machine
# API_BASE_URL should be http://localhost:8081 (default)

# If using Android emulator
# API_BASE_URL should be http://10.0.2.2:8081 (special IP for emulator → host)
# Set in code or environment:
export API_BASE_URL=http://10.0.2.2:8081
flutter run -d emulator-5554

# If using physical device on same network
# API_BASE_URL should be http://[host-machine-ip]:8081
# Find host IP: ifconfig | grep inet
export API_BASE_URL=http://192.168.1.100:8081
```

### Issue: Database migration failed

**Solution**:
```bash
# Check if migrations ran
docker logs messenger-backend | grep -i migration

#  Reset database (CAUTION: deletes all data)
docker-compose down
docker volume prune -f
docker-compose up --build
```

### Issue: WebSocket connection timeouts

**Solution**:
```bash
# Check firewall allows WebSocket
# WSS (secure) uses port 8081 by default

# Test WebSocket directly
wscat -c ws://localhost:8081/ws/messages

# If connection unstable, polling fallback should engage automatically
# Check frontend logs for fallback engagement
```

---

## Development Tips

### Hot Reload
```bash
# Frontend hot reload (keep app running)
Press 'r' in terminal to hot reload
Press 'R' to hot restart (rebuilds app)

# Backend hot reload
cd backend
dart run --hot bin/server.dart
# (Note: may not work for all changes; full restart sometimes needed)
```

### Debugging Frontend
```bash
# Run with verbose logging
flutter run -v

# Debug mode with breakpoints (VS Code)
# Set breakpoint in code
# Run: F5 in VS Code (with Dart plugin)
# Step through execution

# Flutter DevTools
flutter pub global activate devtools
flutter pub global run devtools
# Then: flutter run --observatory-port 7777
```

### Debugging Backend
```bash
# Run backend in debug mode
cd backend
dart run --observe bin/server.dart

# Connect Dart analyzer to debugger
# Use IDE debugger console to inspect state
```

---

## Production-Like Testing

### Simulate Network Latency
```bash
# Add 100ms latency to all traffic (macOS/Linux)
sudo tc qdisc add dev lo root netem delay 100ms

# Remove latency
sudo tc qdisc del dev lo root netem

# Simulate packet loss (10%)
sudo tc qdisc add dev lo root netem loss 10%
```

### Test on Real Devices
```bash
# Stop backend on localhost
# Deploy backend to staging server: example.com

# Configure frontend to use staging
export API_BASE_URL=https://example.com

# Build APK for Android testing
flutter build apk --release -t lib/main.dart

# Install on device
adb install build/app/outputs/flutter-app-release.apk

# Or iOS
flutter build ios --release
# Then open in Xcode and deploy
```

---

## Next Steps

1. **Run Local Tests**: Execute the four test flows above
2. **Review Data Model**: Check [data-model.md](../data-model.md) for schema
3. **Review API Contracts**: Check [contracts/websocket.md](../contracts/websocket.md) for event formats
4. **Explore Code**: Look at existing chat feature in `frontend/lib/features/chats/` for patterns
5. **Begin Implementation**: See main [plan.md](../plan.md) for Phase 2 task breakdown

---

## Support

- **Backend Issues**: Check backend logs via `docker logs messenger-backend`
- **Frontend Issues**: Check Flutter console output for error traces
- **Database Issues**: Manual inspection via `docker exec -it messenger-postgres psql`
- **Tests Failing**: Run with `-v` flag for verbose output and full stack traces

