# Implementation Plan: Chat List & Messaging

**Branch**: `019-chat-list` | **Date**: 2026-03-15 | **Spec**: [specs/019-chat-list/spec.md](../specs/019-chat-list/spec.md)
**Input**: Feature specification from `/specs/019-chat-list/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Build real-time chat messaging on top of the completed invitation system. The feature enables users to view accepted chats sorted by recency, send/receive messages in real-time, and archive inactive conversations. Backend: PostgreSQL `chats` and `messages` tables + Shelf HTTP/WebSocket endpoints. Frontend: Riverpod providers for chat list state, Flutter UI with message input/display, automatic sync on app open. MVP scope: P1 features (View, Send/Receive); P2 (Archive) deferred. All message content encrypted end-to-end using cryptography library. Deliverables: Backend API endpoints, Frontend screens/providers, database schema, test suite (unit + 2-user integration), Android APK, updated README.

## Technical Context

**Language/Version**: Dart 3.11.1 (Flutter 3.41.4 mobile) + Dart backend (Shelf)  
**Primary Dependencies**: Riverpod (state management), Provider (auth), Shelf (HTTP server), PostgreSQL driver, cryptography  
**Storage**: PostgreSQL with tables: `users`, `chats`, `messages`, `invites`  
**Testing**: Flutter widget tests, integration tests (2-user flows), Shelf API contract tests  
**Target Platform**: Android (emulator via WSL2 at 172.31.195.26:8081, physical devices), iOS  
**Project Type**: Mobile app (Flutter frontend) + Backend service (Shelf + PostgreSQL)  
**Performance Goals**: <500ms chat list load time, <2s message delivery end-to-end, real-time updates  
**Constraints**: End-to-end encryption required (cryptography library), offline message queueing preferred, single docker-compose startup  
**Scale/Scope**: 2-N user messaging with chat history persistence, archived chats support

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| **I. Security-First** | All message content E2E encrypted before storage/transmission | ⚠️ DESIGN GATE | Must define encryption key exchange in Phase 1; cryptography library usage in message handlers |
| **III. Testing Discipline** | Three-tier: (1) Unit tests per module, (2) Manual UI emulator testing, (3) Two-user integration message flow | ⚠️ DESIGN GATE | Must specify test cases for each user story; 2-user acceptance test scenario documented in Phase 1 |
| **IV. Code Consistency** | File names snake_case, classes PascalCase, functions camelCase | ✅ PASS | Existing codebase adheres; new files follow: `chat_service.dart`, `ChatModel`, `fetchChats()` |
| **II. Architecture Clarity** | Frontend (Flutter) ↔ Backend (Shelf) via HTTP/WebSocket; PostgreSQL storage | ⚠️ DESIGN GATE | Phase 1 must diagram layer boundaries and data flow; specify real-time sync mechanism (WebSocket vs polling) |
| **V. Delivery Readiness** | `docker-compose up` starts backend; Android APK built; README with reviewer guide | ⚠️ BUILD GATE | Phase 1 to confirm backend service added to docker-compose.yml; Phase 2 to validate APK build and README updates |

## Project Structure

### Documentation (this feature)

```text
specs/019-chat-list/
├── plan.md              # This file (/speckit.plan command output)
├── spec.md              # Feature specification (completed)
├── research.md          # Phase 0 output (/speckit.plan command) - research findings on architecture
├── data-model.md        # Phase 1 output - Chat, Message entity definitions
├── quickstart.md        # Phase 1 output - guide to test feature locally
├── contracts/           # Phase 1 output - API contract specs
│   ├── chat-api.md      # GET /api/chats, POST /api/chats/{id}/messages
│   └── websocket.md     # Real-time message events
├── checklists/
│   └── requirements.md  # Quality validation (completed: PASSED ✅)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code: Frontend (Dart/Flutter)

```text
frontend/
├── lib/
│   ├── features/
│   │   ├── chats/                           # NEW: Chat list and messaging
│   │   │   ├── screens/
│   │   │   │   ├── chat_list_screen.dart    # Display chats sorted by recency
│   │   │   │   ├── chat_detail_screen.dart  # Message thread and input
│   │   │   │   └── archived_chats_screen.dart # P2 feature
│   │   │   ├── providers/
│   │   │   │   ├── chats_provider.dart      # ALL chats (Riverpod async selector)
│   │   │   │   ├── active_chats_provider.dart    # Filtered for main list
│   │   │   │   ├── messages_provider.dart  # Chat-specific message history
│   │   │   │   ├── send_message_provider.dart   # Mutation notifier
│   │   │   │   └── chat_cache_invalidator.dart  # Refresh cache on login (similar to invites)
│   │   │   ├── models/
│   │   │   │   ├── chat_model.dart         # Chat entity JSON serialization
│   │   │   │   └── message_model.dart      # Message entity, encrypted content
│   │   │   ├── services/
│   │   │   │   ├── chat_api_service.dart   # HTTP client for /api/chats endpoints
│   │   │   │   └── message_encryption_service.dart # E2E encryption wrapper
│   │   │   └── widgets/
│   │   │       ├── chat_list_tile.dart     # Individual chat row with last message
│   │   │       ├── message_bubble.dart     # Sent/received message display
│   │   │       └── message_input_box.dart  # Text input + send button
│   │   └── invitations/                    # Existing (no changes required)
│   ├── core/
│   │   ├── services/
│   │   │   ├── api_client.dart             # HTTP client (existing, base URL confirmed)
│   │   │   ├── secure_storage.dart         # Token storage (existing)
│   │   │   └── websocket_service.dart      # NEW: WebSocket real-time connection
│   │   └── models/
│   │       ├── user_model.dart
│   │       └── error_model.dart
│   └── app.dart                            # Root widget (existing: ConsumerStatefulWidget)
└── test/
    ├── features/chats/
    │   ├── providers/
    │   │   └── chats_provider_test.dart     # Unit test for Riverpod logic
    │   ├── services/
    │   │   ├── chat_api_service_test.dart   # Contract test for /api/chats
    │   │   └── message_encryption_test.dart # Encryption round-trip test
    │   └── screens/
    │       ├── chat_list_screen_test.dart   # Widget test
    │       └── chat_detail_screen_test.dart # Widget + interaction test
    └── integration_tests/
        └── messaging_flow_test.dart         # 2-user scenario: send/receive
```

### Source Code: Backend (Dart/Shelf)

```text
backend/
├── lib/
│   ├── src/
│   │   ├── models/
│   │   │   ├── chat_model.dart             # NEW: Chat entity + JSON serialization
│   │   │   └── message_model.dart          # NEW: Message + encrypted_content field
│   │   ├── services/
│   │   │   ├── chat_service.dart           # NEW: Business logic for chat ops
│   │   │   └── message_service.dart        # NEW: Validation + E2E crypto wrapper
│   │   ├── database/
│   │   │   ├── migrations/
│   │   │   │   └── 003_create_chats_messages.sql  # NEW: Schema for chats, messages
│   │   │   └── queries/
│   │   │       ├── chat_queries.dart       # SQL helpers for chat queries
│   │   │       └── message_queries.dart    # SQL helpers for message queries
│   │   ├── handlers/
│   │   │   ├── chat_handlers.dart          # NEW: Shelf route handlers for /api/chats
│   │   │   ├── message_handlers.dart       # NEW: POST /api/chats/{id}/messages
│   │   │   └── websocket_handler.dart      # NEW: WebSocket endpoint for real-time
│   │   ├── middleware/
│   │   │   └── auth_middleware.dart        # Verify JWT token (existing)
│   │   ├── config.dart                     # Database config (existing)
│   │   └── server.dart                     # Main server setup (modify to add /api/chats routes)
│   └── main.dart                           # Entry point (no changes)
└── test/
    ├── models/
    │   └── message_model_test.dart          # JSON serialization, encryption
    ├── services/
    │   ├── chat_service_test.dart           # Business logic
    │   └── message_encryption_test.dart     # Crypto wrapper test
    └── handlers/
        ├── chat_handlers_test.dart          # HTTP contract test
        └── websocket_handler_test.dart      # Connection + event broadcast test
```

### Database Schema (PostgreSQL)

```sql
-- NEW tables for 019-chat-list feature
CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant_1_id UUID REFERENCES users(id) ON DELETE CASCADE,
    participant_2_id UUID REFERENCES users(id) ON DELETE CASCADE,
    is_participant_1_archived BOOLEAN DEFAULT FALSE,
    is_participant_2_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(participant_1_id, participant_2_id)
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    encrypted_content TEXT NOT NULL,  -- Base64 encoded E2E encrypted message
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_chats_participant_1 ON chats(participant_1_id, updated_at DESC);
CREATE INDEX idx_chats_participant_2 ON chats(participant_2_id, updated_at DESC);
CREATE INDEX idx_messages_chat_created ON messages(chat_id, created_at DESC);
```

**Structure Decision**: Mobile + API architecture (Option 3) selected based on Flutter frontend + Dart backend. Backend service will use existing docker-compose with new PostgreSQL schema. Frontend new feature module at `lib/features/chats/` follows established Riverpod + Provider pattern from invitations system. Backend handlers added to existing Shelf server routes.

## Complexity Tracking

| Item | Justification | Rationale |
|------|---------------|-----------|
| No Constitution violations | All design decisions align with project constitution | E2E encryption, multi-layer architecture, 3-tier testing, naming standards all required/expected for this project scale |
