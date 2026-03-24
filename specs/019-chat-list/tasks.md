# Implementation Tasks: Chat List & Messaging

**Feature**: 019-chat-list | **Branch**: `019-chat-list` | **Status**: Phase 2 Task Breakdown  
**Total Tasks**: 54 | **Phases**: 6 | **Dependency Groups**: 4

---

## Overview & Execution Strategy

### Phase Organization

- **Phase 1**: Setup (project initialization + dependencies) - 3 tasks
- **Phase 2**: Foundational (blocking prerequisites) - 8 tasks  
- **Phase 3**: User Story 1 (View Chat List) - 12 tasks
- **Phase 4**: User Story 2 (Send/Receive Messages) - 16 tasks
- **Phase 5**: User Story 3 (Archive Chats) - 8 tasks
- **Phase 6**: Polish & Cross-Cutting (integration, testing, deployment) - 7 tasks

### MVP Scope

Complete Phase 1 → Phase 2 → Phase 3 → Phase 4 for MVP delivery.  
Phase 5 (Archive) deferred to v1.1 if needed.  
Phase 6 required before production release.

### Parallelization Opportunities

- **Parallel Set 1**: Backend model/service implementation (T017-T021 can run in parallel)
- **Parallel Set 2**: Frontend screens/providers independent setup (T024-T028 can run in parallel)
- **Parallel Set 3**: Backend & frontend testing (T047-T050 can run in parallel after code complete)

### Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundation: DB, API routes, providers) 
    ├─ Phase 3 (US1: Chat List) [depends on Phase 2]
    ├─ Phase 4 (US2: Messages) [depends on Phase 2, Phase 3]
    └─ Phase 5 (US3: Archive) [depends on Phase 2, Phase 3]
    
All ↓
Phase 6 (Polish, integration, APK, README)
```

---

## Phase 1: Setup (Project Initialization)

- [x] T001 Create project directory structure for chats feature module at `frontend/lib/features/chats/`
- [x] T002 Update `pubspec.yaml` to add Web Socket channel dependency for real-time messaging
- [x] T003 Add PostgreSQL migration file `backend/migrations/003_create_chats_messages.sql` with schema

---

## Phase 2: Foundational (Infrastructure & Prerequisites)

### Backend: Database & Core Services

- [x] T004 Create PostgreSQL schema migration: `chats` and `messages` tables with indexes (execute `.sql` file from T003)
- [x] T005 [P] Create backend model file `backend/lib/src/models/chat_model.dart` with Chat entity, JSON serialization, helper methods
- [x] T006 [P] Create backend model file `backend/lib/src/models/message_model.dart` with Message entity, encrypted_content field, JSON serialization
- [x] T007 [P] Create backend service `backend/lib/src/services/chat_service.dart` with methods: getActiveChats(), getMessages(), createChat()
- [x] T008 [P] Create backend service `backend/lib/src/services/message_service.dart` with methods: sendMessage(), validateMessage(), encryption wrapper

### Backend: WebSocket Infrastructure

- [x] T009 Create WebSocket connection manager at `backend/lib/src/services/websocket_service.dart` with broadcast logic

### Frontend: Core Providers & Services

- [x] T010 [P] Create frontend model file `frontend/lib/features/chats/models/chat_model.dart` with Chat entity, JSON serialization
- [x] T011 [P] Create frontend model file `frontend/lib/features/chats/models/message_model.dart` with Message entity, encrypted_content, decryption helper

---

## Phase 3: User Story 1 - View Chat List (P1)

### Acceptance: Display chats sorted by recency, tap to open conversation

### Backend: Chat List API Endpoints

- [x] T012 [US1] Create HTTP handlers in `backend/lib/src/handlers/chat_handlers.dart` for `GET /api/chats` endpoint (fetch active chats, sorted by updated_at DESC)
- [x] T013 [US1] Implement chat_handlers.dart: JWT auth verification middleware, user context extraction
- [x] T014 [US1] Add database query helpers in `backend/lib/src/database/queries/chat_queries.dart` for efficient chat list fetches (with indexes)
- [x] T015 [US1] Integrate chat handlers into main server routes at `backend/lib/src/server.dart` (add Router mount for /api/chats)

### Backend: Message History Endpoint

- [x] T016 [US1] Create HTTP handler for `GET /api/chats/{chatId}/messages` in chat_handlers.dart (cursor pagination, 20 messages/request)

### Frontend: Chat Services

- [x] T017 [US1] [P] Create API client `frontend/lib/features/chats/services/chat_api_service.dart` with methods: fetchChats(), fetchMessages()
- [x] T018 [US1] [P] Create encryption service `frontend/lib/features/chats/services/message_encryption_service.dart` for E2E decryption wrapper

### Frontend: Riverpod Providers

- [x] T019 [US1] [P] Create provider `frontend/lib/features/chats/providers/chats_provider.dart` (FutureProvider for all chats)
- [x] T020 [US1] [P] Create provider `frontend/lib/features/chats/providers/active_chats_provider.dart` (Selector filtering archived chats)
- [x] T021 [US1] [P] Create provider `frontend/lib/features/chats/providers/chat_cache_invalidator.dart` (StateProvider<int> for version control)

### Frontend: Chat List Screen & Widgets

- [x] T022 [US1] Create widget `frontend/lib/features/chats/widgets/chat_list_tile.dart` (displays friend name, last message preview, timestamp)
- [x] T023 [US1] Create screen `frontend/lib/features/chats/screens/chat_list_screen.dart` (Consumer widget, lists chats from activeChatProvider, handles empty state)
- [x] T024 [US1] Add ChatListTab to `frontend/lib/app.dart` bottom navigation (tap to navigate to chat_list_screen.dart)
- [x] T025 [US1] Implement auto-refresh on login in `app.dart`: increment chatsCacheInvalidatorProvider.notifier.state++ in login callback

### Frontend: Chat Detail Screen (US1 Integration)

- [x] T026 [US1] Create screen `frontend/lib/features/chats/screens/chat_detail_screen.dart` (displays message history, placeholder for message input - implemented in US2)

### Integration Test: US1 E2E

- [x] T027 [US1] Create 2-user integration test `frontend/test/integration_tests/chat_list_flow_test.dart`: Create 2 chats → Verify sorting by recency → Tap chat → Verify detail screen loads

---

## Phase 4: User Story 2 - Send & Receive Messages (P1)

### Acceptance: Send messages, receive in real-time (<2s), persist history

### Backend: Message Sending Endpoint

- [x] T028 [US2] Create HTTP handler in `backend/lib/src/handlers/message_handlers.dart` for `POST /api/chats/{chatId}/messages` (accept encrypted_content, sender validation)
- [x] T029 [US2] Implement message_handlers.dart: Sender verification (must be chat participant), encryption validation, idempotency check

### Backend: Message Validation & Encryption

- [x] T030 [US2] Implement in message_service.dart: validateMessage() (check sender, size <10KB, content non-empty)
- [x] T031 [US2] Implement in message_service.dart: E2E encryption wrapper using cryptography library (ChaCha20-Poly1305)

### Backend: WebSocket Real-Time Layer

- [x] T032 [US2] Create WebSocket handler in `backend/lib/src/handlers/websocket_handler.dart` (upgrade connection, authenticate JWT, broadcast message events)
- [x] T033 [US2] Implement websocket_handler.dart: Parse incoming events, validate, broadcast to both chat participants
- [x] T034 [US2] Add WebSocket route to `backend/lib/src/server.dart` (`GET /ws/messages`)
- [x] T035 [US2] Implement heartbeat/keep-alive in WebSocket (ping/pong every 30 seconds)

### Frontend: Message Providers

- [ ] T036 [US2] [P] Create provider `frontend/lib/features/chats/providers/messages_provider.dart` (FutureProvider family for chat-specific messages)
- [ ] T037 [US2] [P] Create provider `frontend/lib/features/chats/providers/send_message_provider.dart` (AsyncNotifier for mutation, refreshes message list on send)

### Frontend: WebSocket Stream Provider

- [ ] T038 [US2] Create provider `frontend/lib/core/services/websocket_service.dart` (Provider<WebSocketService> managing connection lifecycle)
- [ ] T039 [US2] Create provider `frontend/lib/features/chats/providers/message_stream_provider.dart` (StreamProvider for real-time message events from WebSocket)

### Frontend: Message UI Widgets

- [ ] T040 [US2] Create widget `frontend/lib/features/chats/widgets/message_bubble.dart` (sent/received bubble, timestamp, encryption indicator)
- [ ] T041 [US2] Create widget `frontend/lib/features/chats/widgets/message_input_box.dart` (text field, send button, loading state)

### Frontend: Chat Detail Screen (Message Integration)

- [ ] T042 [US2] Update screen `frontend/lib/features/chats/screens/chat_detail_screen.dart` (add MessagesProvider listener, message bubbles list, input box, send handler)
- [ ] T043 [US2] Implement message sending logic in chat_detail_screen.dart: Encrypt message → Call sendMessageProvider → Refresh on success

### Integration Test: US2 E2E

- [ ] T044 [US2] Create 2-user integration test `frontend/test/integration_tests/messaging_flow_test.dart`: Open chat → Send message Alice → Receive on Bob (WebSocket) → Reply → Verify message history persists

---

## Phase 5: User Story 3 - Archive Chats (P2)

### Acceptance: Long-press chat → Archive → Move to Archived view → Unarchive restores

### Backend: Archive Endpoint

- [ ] T045 [US3] Create HTTP handler in `backend/lib/src/handlers/chat_handlers.dart` for `PUT /api/chats/{chatId}/archive` (update per-user archive flag, broadcast event)

### Frontend: Archive Providers & Logic

- [ ] T046 [US3] Create provider `frontend/lib/features/chats/providers/archived_chats_provider.dart` (Selector for archived chats)

### Frontend: Archive UI & Navigation

- [ ] T047 [US3] Create screen `frontend/lib/features/chats/screens/archived_chats_screen.dart` (tab view of archived chats with unarchive button)
- [ ] T048 [US3] Update chat_list_screen.dart: Add long-press gesture on ChatListTile → Show archive/unarchive context menu
- [ ] T049 [US3] Add Archive/Unarchived tabs to chat_list_screen.dart (or separate navigation)

### Integration Test: US3 E2E

- [ ] T050 [US3] Create test `frontend/test/integration_tests/archive_flow_test.dart`: Archive chat → Verify removed from main list → Tap Archived → Verify visible → Unarchive → Verify restored

---

## Phase 6: Polish, Integration & Deployment

### Database & Schema Validation

- [ ] T051 Create integration test `backend/test/database_migration_test.dart` (verify tables created, constraints applied, indexes present)

### Backend Testing

- [ ] T052 [P] Create contract test `backend/test/handlers/chat_handlers_test.dart` (test all /api/chats/* endpoints with various payloads)
- [ ] T053 [P] Create unit test `backend/test/services/message_encryption_test.dart` (round-trip: plaintext → encrypt → decrypt, verify output)
- [ ] T054 [P] Create unit test `backend/test/services/chat_service_test.dart` (getActiveChats sorting, getMessages pagination)

### Frontend Widget Tests

- [ ] T055 [P] Create widget test `frontend/test/features/chats/screens/chat_list_screen_test.dart` (render, empty state, chat tile display)
- [ ] T056 [P] Create widget test `frontend/test/features/chats/screens/chat_detail_screen_test.dart` (message bubbles, input box interaction)

### Firebase/Deployment

- [ ] T057 Update `docker-compose.yml` to confirm backend service starts correctly with chat endpoints (verify no new service needed)
- [ ] T058 Build Android APK and test on emulator with 2-user flow (verify <500ms list load, <2s message delivery per performance goals)

### Documentation & README

- [ ] T059 Update `backend/README.md` with Chat List feature overview and API endpoint documentation
- [ ] T060 Update `frontend/README.md` with Chat List screens, testing guide, and known limitations

---

## Quality Gates & Validation

### Pre-Merge Checklist (Per Constitution)

- [ ] **Security-First**: All message content encrypted (ChaCha20) before DB storage (T031 completed)
- [ ] **Code Consistency**: All file names snake_case, classes PascalCase, functions camelCase (validate via linting)
- [ ] **Testing Discipline**: Unit tests (T052-T056) + Contract tests (T052) + 2-user integration flow (T044, T050) all passing
- [ ] **Architecture Clarity**: HTTP endpoints (T012-T016) + WebSocket layer (T032-T035) + PostgreSQL schema (T004) documented in plan.md

### Performance Validation (Per Success Criteria)

- [ ] SC-001: Chat list loads in <500ms (measure T023 performance)
- [ ] SC-002: Message delivery <2s end-to-end (validate WebSocket latency in T044)
- [ ] SC-003: Chat sorting 100% accurate (verify sort in T027)
- [ ] SC-004: Archive/unarchive 100% success rate (verify T050 passes consistently)
- [ ] SC-005: Message history persists (verify after app restart in T044)

---

## Task Dependency Graph

```
T001-T003 (Setup)
    ↓
T004-T011 (Foundation: DB, models, services)
    ├─ T012-T027 (US1: Chat List) [depends on T005-T011]
    │   ├─ T028-T044 (US2: Messages) [depends on T006-T008, T012-T027]
    │   │   └─ T045-T050 (US3: Archive) [depends on T012-T027]
    │   └─ 
    ├─ T045-T050 (US3: Archive) [depends on T005, T012]
    │
    └─ T051-T060 (Phase 6: Polish, tests, deployment) [depends on ALL]
```

---

## Estimated Effort

| Phase | Tasks | Estimated Hours | Lead |
|-------|-------|-----------------|------|
| Phase 1 | 3 | 0.5 | Setup |
| Phase 2 | 8 | 4 | Backend models, frontend providers |
| Phase 3 | 16 | 8 | Chat list screens, HTTP endpoints |
| Phase 4 | 16 | 12 | Message sending, E2E encryption, WebSocket |
| Phase 5 | 8 | 3 | Archive UI, archive flag logic |
| Phase 6 | 7 | 5 | Testing, documentation, APK build |
| **Total** | **58** | **32.5** | **~4 days (8h/day)** |

---

## Success Criteria for Each Phase

**Phase 1 ✅**: Directory structure created, migrations prepared  
**Phase 2 ✅**: All models & services scaffold complete, DB schema in postgres  
**Phase 3 ✅**: Chat list renders with real data, sorted correctly  
**Phase 4 ✅**: 2-user message flow end-to-end working, <2s delivery verified  
**Phase 5 ✅**: Archive feature working independently  
**Phase 6 ✅**: All tests passing, APK builds, README updated, ready for release

---

## Notes for Implementer

1. **Encryption Key Exchange**: Deferred to Phase 1.1 - assume keys pre-shared via invitation flow for now
2. **Offline Queueing**: Deferred to v1.1 - MVP assumes connectivity for <2s target
3. **Error Handling**: All T028-T035 should include try/catch with user-friendly error messages
4. **Testing Strategy**: Follow 3-tier approach (Unit → Widget → 2-User Integration)
5. **Performance**: Monitor T023 and T044 performance metrics; if >500ms or >2s, profile and optimize queries
