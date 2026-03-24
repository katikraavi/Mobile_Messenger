# Tasks: Chat List Last Message Preview

**Input**: plan.md, spec.md

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 Ensure chat and message models are up-to-date in frontend/lib/features/chats/models/
- [ ] T002 [P] Confirm backend API returns last message and timestamp for each chat (Serverpod)
- [ ] T003 [P] Validate WebSocket real-time updates for chat list

---

## Phase 2: Foundational (Blocking Prerequisites)

- [ ] T004 [P] Update frontend/lib/features/chats/services/chat_api_service.dart to fetch last message preview and timestamp
- [ ] T005 [P] Update frontend/lib/features/chats/providers/chats_provider.dart to include last message and timestamp in chat list data
- [ ] T006 [P] Ensure message types (text, media) are handled in frontend/lib/features/chats/models/message_model.dart

---

## Phase 3: User Story 1 - Last Message Preview (P1)

**Goal**: Display last message preview and timestamp under each chat participant's name
**Independent Test**: Send messages and verify preview/timestamp update in chat list

---
## Phase 4: User Story 2 - Chat List Ordering (P2)

**Goal**: Sort chats by most recent message
**Independent Test**: Send messages in different chats and verify order updates

- [ ] T010 [P] [US2] Sort chat list in frontend/lib/features/chats/screens/chat_list_screen.dart by last message timestamp (descending)
---
## Phase 5: User Story 3 - Real-Time Update (P3)

**Goal**: Update chat list immediately when new message arrives
---

## Final Phase: Polish & Cross-Cutting Concerns


---

- T004, T005, T006 → T007, T008, T009
- T007, T008, T009 → T010, T011
- T010, T011 → T012, T013

 [X] T008 [US1] Show "No messages yet" for chats with no messages
 [X] T009 [US1] Add media indicator (e.g., "[Photo]", "[Audio]") for media messages
 T014, T015, T016, T017, T018 can run in parallel

## Implementation Strategy

- MVP: Complete User Story 1 (T007, T008, T009)
- Incremental delivery: Add ordering (User Story 2), then real-time update (User Story 3)
- Ensure encryption validation and user picture logic are tested and documented
