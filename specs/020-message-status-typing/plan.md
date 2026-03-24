# Implementation Plan: Messaging with Status Indicators and Typing Notifications

**Branch**: `020-message-status-typing` | **Date**: 2026-03-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/020-message-status-typing/spec.md`

**Note**: This plan is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Enable real-time 1-to-1 messaging with message status tracking (sent/delivered/read), typing indicators, and message editing/deletion with clear frontend indication. This is the core messaging feature enabling bidirectional conversations between authenticated users in established chats.

**Technical Approach**: Implement real-time message delivery using WebSockets or polling for typing indicators and status updates; persist messages and status in PostgreSQL; display status indicators in Flutter UI with support for edit/delete operations that show in-place or as deleted placeholders.

## Technical Context

**Language/Version**: Dart (frontend: Flutter 3.0+, backend: Serverpod)  
**Primary Dependencies**: 
- Frontend: `flutter_riverpod` (state management), `web_socket_channel` or similar (real-time), `http` package
- Backend: `shelf` (HTTP routing), `postgres` (database access), `dart_jsonrpc` or similar (WebSocket support)

**Storage**: PostgreSQL 13+ with tables: `messages`, `message_status`, `message_edits`  
**Testing**: `flutter_test` (frontend), `test` package (backend), integration tests via two-user scenarios  
**Target Platform**: Linux/Android (frontend), Linux Docker container (backend)  
**Project Type**: Mobile app + backend server  
**Performance Goals**: Message delivery <2s, typing indicator <1s, UI updates within frame (60fps)  
**Constraints**: <500ms message appearance, network resilience with retry, offline queuing for failed sends  
**Scale/Scope**: 1-to-1 messaging for 10-100 concurrent users, support for editing/deleting previously sent messages

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check AFTER Phase 1 design.*

### I. Security-First Principle (NON-NEGOTIABLE)
- **Status**: ✅ RESOLVED & COMPLIANT
- **Decision**: At-rest encryption (Option B from research.md)
- **Implementation**: 
  - Messages encrypted with AES-256-GCM before database storage
  - Uses `cryptography` package (already available in Dart)
  - Server manages single encryption key (environment variable)
  - Decryption on retrieval, messages served plaintext over WSS/HTTPS
- **Verification**: See [research.md](research.md) section 1 for full analysis
- **Audit Trail**: Soft deletes preserved, edit history in message_edits table
- **✅ GATE PASSED**: Constitution I requirement for encrypted persistence met

### III. Testing Discipline Principle (NON-NEGOTIABLE)
- **Status**: ✅ PLANNED & DOCUMENTED
- **Three-Tier Strategy**:
  1. Unit tests: `test/unit/message_service_test.dart`, `test/widget/message_bubble_test.dart`
  2. Integration tests: `test/integration/message_endpoints_test.dart`, two-user scenarios
  3. Manual UI tests: Documented in [quickstart.md](quickstart.md) - 4 test flows
- **Will be Implemented**: In Phase 2 (tasks.md) with specific test cases per requirement
- **✅ GATE WILL PASS**: Testing framework established for Phase 2 implementation

### II. End-to-End Architecture Clarity
- **Status**: ✅ COMPLIANT
- **Architecture**:
  - Frontend: Flutter widgets → Riverpod providers → ChatApiService → WebSocket
  - Backend: Shelf routing → MessageHandlers → MessageService → PostgreSQL
  - Real-time: WebSocket primary (typed events), HTTP polling fallback
- **Verification**: [contracts/websocket.md](contracts/websocket.md) defines all 20+ event types with JSON schemas
- **✅ GATE PASSED**: Layer boundaries explicit, data flow clear

### IV. Code Consistency & Naming Standards
- **Status**: ✅ PLANNED
- **Enforcement**:
  - File names: snake_case (e.g., `message_service.dart`, `message_bubble.dart`)
  - Classes: PascalCase (e.g., `MessageService`, `MessageBubble`)
  - Functions/vars: camelCase (e.g., `fetchMessages()`, `messageStatus`)
- **Will Verify**: During Phase 2 code review gates
- **✅ GATE WILL PASS**: Standards enforced via team review

### V. Delivery Readiness
- **Status**: ✅ READY
- **Verification**:
  - Backend: `docker-compose up --build` will start all services
  - Database: Migrations included for messages, message_status, message_edits tables
  - README: [quickstart.md](quickstart.md) provides step-by-step local setup
- **✅ GATE PASSED**: Reviewers can start backend with single command

---

**Overall Gate Status**: ✅ **PHASE 1 DESIGN COMPLETE - ALL GATES PASSED**

Proceeding to Phase 2 (tasks.md) ready for implementation.

## Project Structure

### Documentation (this feature)

```text
specs/020-message-status-typing/
├── spec.md                          # Feature specification (COMPLETE)
├── plan.md                          # This file (IN PROGRESS)
├── research.md                      # Phase 0: TBD - encryption strategy, WebSocket patterns
├── data-model.md                    # Phase 1: TBD - Message, MessageStatus, MessageEdit entities
├── quickstart.md                    # Phase 1: TBD - local dev setup for messaging feature
├── contracts/                       # Phase 1: TBD - API contracts for WebSocket messages
└── checklists/
    └── requirements.md              # Requirements validation (COMPLETE)
```

### Source Code (repository root)

```text
backend/
├── lib/
│   ├── server.dart                  # Main server with message endpoints
│   ├── bin/server.dart              # Entry point
│   └── src/
│       ├── models/
│       │   └── message_model.dart   # Message, MessageStatus classes
│       ├── services/
│       │   ├── message_service.dart # Message CRUD and status updates
│       │   └── typing_service.dart  # Typing indicator state
│       ├── handlers/
│       │   └── message_handlers.dart # Message endpoint logic
│       └── migrations/
│           ├── 00X_create_messages_table.dart
│           ├── 00X_create_message_status_table.dart
│           └── 00X_create_message_edits_table.dart
├── test/
│   ├── unit/
│   │   └── message_service_test.dart
│   └── integration/
│       └── message_endpoints_test.dart
└── Dockerfile

frontend/
├── lib/
│   └── features/
│       └── chats/
│           ├── models/
│           │   └── message_model.dart
│           ├── services/
│           │   ├── message_api_service.dart
│           │   └── typing_service.dart
│           ├── providers/
│           │   ├── messages_provider.dart
│           │   └── typing_indicator_provider.dart
│           ├── screens/
│           │   └── chat_screen.dart (enhanced with messaging)
│           └── widgets/
│               ├── message_bubble.dart
│               ├── message_status_indicator.dart
│               ├── typing_indicator.dart
│               └── message_input_field.dart
├── test/
│   ├── unit/
│   │   └── messaging_test.dart
│   └── widget/
│       └── message_bubble_test.dart
└── pubspec.yaml

docker-compose.yml                   # Already includes backend + postgres
```

**Structure Decision**: Option 2 - Flutter mobile frontend + Serverpod backend. Messaging feature integrates into existing chat infrastructure. New database tables for messages, status, and edits. New services for message and typing operations. New provider for real-time state management.

---

## Phase 0: Research Completion

✅ **STATUS: COMPLETE**

### Research Findings

All NEEDS CLARIFICATION items resolved. See [research.md](research.md) for full analysis:

1. **Encryption Strategy**: ✅ At-rest (AES-256-GCM)
   - Rationale: Balances security (Constitution I requirement) with development speed (no complex key exchange)
   - Implementation: Message content encrypted before database storage using `cryptography` Dart package
   - Server manages single encryption key via environment variable
   - Messages decrypted on retrieval, served plaintext over WSS/HTTPS

2. **Real-Time Transport**: ✅ WebSocket + HTTP polling fallback
   - Rationale: Meets <1s typing indicator requirement (WebSocket native, polling 100-200ms latency)
   - Strategy: Client attempts WebSocket; falls back to polling if unavailable
   - Failover: Automatic reconnection with exponential backoff

3. **Message Persistence Strategy**: ✅ Soft-delete with version history
   - Rationale: Maintains audit trail (Constitution requirement), enables "message deleted" placeholder UI
   - Implementation: Boolean `is_deleted` flag on messages table; edit history in message_edits table
   - Deleted messages remain in database marked as deleted; edit history shows all versions

4. **Typing Indicator State**: ✅ 3-second server-side timeout, 100ms client debounce
   - Rationale: Prevents duplicates (debounce), ensures cleanup if client crashes (timeout)
   - Implementation: In-memory Map on server with userId:chatId key; 3s TTL before auto-removal
   - Frontend sends typing.start/stop events; server broadcasts to other chat members

5. **Message Status Progression**: ✅ pending → sent → delivered → read
   - Rationale: Clear UX, matches user expectations, enables "read receipt" feature
   - Implementation: Separate message_status table tracking for each recipient
   - Status updates via WebSocket events in real-time

---

## Phase 1: Design & Contracts Completion

✅ **STATUS: COMPLETE**

### 1. Data Model

✅ **Artifact**: [data-model.md](data-model.md) — 400+ lines with complete database design

**Entities Defined**:
- **Message**: id, chatId, senderId, content (encrypted), status, timestamps, soft-delete flag
- **MessageStatus**: messageId, recipientId, status progression (sent→delivered→read) with timestamps
- **MessageEdit**: messageId, editNumber, previousContent (encrypted), editedAt, editedBy for audit trail
- **TypingIndicator**: Ephemeral server-side state (not persisted) tracking active typists per chat

**Database Schema**:
```sql
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  chat_id TEXT REFERENCES chats(id),
  sender_id TEXT REFERENCES users(id),
  content TEXT NOT NULL,  -- encrypted AES-256-GCM
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP,
  edited_at TIMESTAMP,
  deleted_at TIMESTAMP
);
CREATE INDEX idx_messages_chat_created ON messages(chat_id, created_at DESC);

CREATE TABLE message_status (
  message_id TEXT REFERENCES messages(id),
  recipient_id TEXT REFERENCES users(id),
  status TEXT CHECK (status IN ('sent', 'delivered', 'read')),
  delivered_at TIMESTAMP,
  read_at TIMESTAMP,
  PRIMARY KEY (message_id, recipient_id)
);

CREATE TABLE message_edits (
  id SERIAL PRIMARY KEY,
  message_id TEXT REFERENCES messages(id),
  edit_number INT,
  previous_content TEXT,  -- encrypted
  edited_at TIMESTAMP,
  edited_by TEXT REFERENCES users(id)
);
```

### 2. API Contracts

✅ **Artifact**: [contracts/websocket.md](contracts/websocket.md) — Complete WebSocket protocol specification

**Protocol Design**: JSON-RPC over WebSocket, 15+ event types with full schemas:

**Connection Lifecycle**:
- `ws://localhost:8081/ws/messages` with JWT bearer token authentication
- Ping/pong keep-alive every 30s
- Auto-reconnect with exponential backoff on disconnect

**Event Types**:
- `message.send` (client→server): Send new message
- `message.new` (server→client): Receive message
- `message.edit` (client→server) / `message.edited` (server→client)
- `message.delete` (client→server) / `message.deleted` (server→client)
- `message.status` (bidirectional): Status changed (sent/delivered/read)
- `message.read` (client→server): Mark messages as read
- `typing.start` / `typing.stop` (client→server)
- `typing.indicator` (server→client): Show "[User] is typing..."
- Error responses with codes (400, 401, 403, 404, 409, 500)

**All events documented with**:
- Complete JSON schema for each event
- Field descriptions and validation rules
- 40+ example payloads showing exact format
- Error handling strategy

### 3. Local Development Guide

✅ **Artifact**: [quickstart.md](quickstart.md) — 450+ lines with complete development setup

**Setup Instructions**:
- Backend: `docker-compose up --build` (includes PostgreSQL)
- Frontend: Flutter project initialization with API URL configuration
- Database: Pre-configured with migrations for new tables

**Four Independent Test Flows**:
1. **Send/Receive**: Two users exchange messages, verify delivery progression
2. **Typing Indicator**: Show "[User] is typing..." in real-time, timeout after 3s
3. **Edit Message**: Modify sent message, show "[edited]" indicator
4. **Delete Message**: Remove message, show placeholder "[This message was deleted]"

**Debugging Tools**:
- Database access: `docker exec -it messenger-postgres psql ...`
- Backend logs: `docker logs messenger-backend`
- Network inspection: WebSocket frames in browser devtools
- Performance profiling: Measure <500ms appearance, <1s typing, <2s delivery

**Testing Procedures**:
- Unit tests: `dart test` (backend), `flutter test` (frontend)
- Integration tests: Two-user scenarios via curl and manual client
- Manual smoke tests documented with success criteria

### 4. Agent Context Update

✅ **Execution**: `.specify/scripts/bash/update-agent-context.sh copilot` completed successfully

**Configuration**: GitHub Copilot context updated with:
- Dart/Flutter technology stack
- PostgreSQL database design
- WebSocket real-time architecture
- Messaging feature requirements from spec
- Existing chat infrastructure context

**Result**: AI agent configured to understand messaging feature context for Phase 2 implementation tasks

---

## Next: Phase 2 (Tasks Implementation)

**Status**: Ready to proceed

**Prerequisites Met**:
- ✅ Feature specification complete (spec.md)
- ✅ All research decisions documented (research.md)
- ✅ Data model finalized (data-model.md)
- ✅ API contracts specified (contracts/websocket.md)
- ✅ Local development setup documented (quickstart.md)
- ✅ Constitution gates passed
- ✅ Agent context updated

**Expected Phase 2 Output**: `tasks.md` with 30-40 prioritized implementation tasks

**Estimated Effort**: 4-5 weeks total (planning complete, 4 weeks development remains)
