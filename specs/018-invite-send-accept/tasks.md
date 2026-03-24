# Tasks: Invitation Send, Accept, Reject, and Cancel

**Feature**: `018-invite-send-accept`  
**Date Generated**: March 15, 2026  
**Status**: Ready for Implementation  
**Input**: spec.md (6 user stories), plan.md (architecture), data-model.md (entities), contracts/api.md (endpoints)

---

## Format Reference

- **[ID]**: Task identifier (T001, T002, etc.) in execution order
- **[P]**: Task can run in parallel (†different files, no blocking dependencies)
- **[Story]**: User story label (US1, US2, US3...)
  - Format: `[US1]` for user story 1 tasks
  - Setup/Foundational phases: NO story label
  - Polish phase: NO story label
- **Description**: Action with exact file paths

---

## Phase 1: Setup (Shared Infrastructure) ✅ COMPLETE

**Purpose**: Project initialization and structure verification

- [x] T001 Verify `invites` table schema in PostgreSQL; confirm sender_id, receiver_id, status, created_at, responded_at columns exist
- [x] T002 Verify PostgreSQL indexes exist: `idx_invites_receiver_status` and `idx_invites_sender_status`
- [x] T003 [P] Verify test user accounts exist (alice, bob, charlie, diane) for manual testing
- [x] T004 [P] Configure backend logging in `backend/lib/server.dart` for invitation operations (debug level for development)

---

## Phase 2: Foundational (Blocking Prerequisites) ⏳ IN PROGRESS (5/6)

**Purpose**: Core infrastructure that MUST be complete before ANY user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 [P] Create Dart model `ChatInviteModel` in `backend/lib/src/models/chat_invite_model.dart` with all fields (id, senderId, senderName, recipientId, recipientName, status, createdAt, respondedAt)
- [x] T006 [P] Create helper function `_invitationRowToJson()` in `backend/lib/server.dart` to convert database rows to invitation DTOs
- [x] T007 Implement authorization validation helper `_validateBearerToken()` in `backend/lib/server.dart` (extracts userId from JWT)
- [ ] T008 Create Flutter model `ChatInviteModel` in `frontend/lib/features/invitations/models/chat_invite_model.dart` with JSON serialization (using freezed or json_serializable)
- [ ] T009 [P] Create `InviteApiService` class in `frontend/lib/features/invitations/services/invite_api_service.dart` with HTTP client + secure storage integration
- [ ] T010 [P] Create Riverpod providers in `frontend/lib/features/invitations/providers/invites_provider.dart` (pendingInvitesProvider, sentInvitesProvider)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Send Invitation to Another User (Priority: P1) 🎯 MVP

**Goal**: Users can send invitations to other users and see confirmation in their sent list

**Independent Test**: Alice sends invitation to Bob → invitation appears in Alice's sent list with status "Pending"

### Implementation for User Story 1

- [ ] T011 [P] [US1] Implement backend endpoint `POST /api/invites` in `backend/lib/server.dart` with:
  - Validate sender_id from Bearer token
  - Validate receiverId exists in users table
  - Check sender_id ≠ receiverId (prevent self-invitations, FR-011)
  - Check no pending invitation already exists (FR-010)
  - Check receiver not in sender's blocked list
  - INSERT into invites table with status='pending', created_at=NOW()
  - Return invitation DTO (SC-001: <2 seconds)

- [ ] T012 [P] [US1] Implement `sendInvitation(receiverId)` method in `frontend/lib/features/invitations/services/invite_api_service.dart`:
  - Read fresh auth token from SecureStorageWrapper
  - POST to `/api/invites` with receiverId
  - Deserialize response to ChatInviteModel
  - Return invitation object

- [ ] T013 [US1] Create `InvitationsScreen` widget in `frontend/lib/features/invitations/screens/invitations_screen.dart`:
  - Display unified invitations list (pending + sent from allInvitesProvider)
  - Show invitation with senderName/recipientName depending on context
  - Show status badge (Pending, Accepted, Rejected, Canceled)

- [ ] T014 [P] [US1] Create "Send Invitation" button component in `frontend/lib/features/invitations/widgets/send_invitation_button.dart`:
  - Trigger sendInvitation() on tap
  - Show loading state during request
  - Show error message if request fails
  - Invalidate sentInvitesProvider on success

- [ ] T015 [US1] Integration: Connect InvitationsScreen to app navigation; add tab/menu item to access invitations screen

- [ ] T016 [US1] Manual test: Alice sends invitation to Bob → verify in sent list within 2 seconds

**Checkpoint**: User Story 1 complete and testable independently

---

## Phase 4: User Story 2 - Recipient Accepts Invitation (Priority: P1)

**Goal**: Recipients can accept invitations and automatically create a chat

**Independent Test**: Bob receives Alice's invitation → Bob accepts → new chat appears in both chat lists

### Implementation for User Story 2

- [ ] T017 [P] [US2] Implement backend endpoint `POST /api/invites/{id}/accept` in `backend/lib/server.dart` with:
  - Validate invitation exists (FR-005)
  - Validate current user is receiver_id
  - Validate status = 'pending'
  - Atomic transaction: 
    - UPDATE invites SET status='accepted', responded_at=NOW()
    - INSERT into chats table with participant_ids=[sender_id, receiver_id], initiated_by_invitation_id=invitation_id (FR-006)
  - Return updated invitation DTO (SC-003: <2 seconds)

- [ ] T018 [P] [US2] Implement `acceptInvitation(invitationId)` method in `frontend/lib/features/invitations/services/invite_api_service.dart`:
  - POST to `/api/invites/{invitationId}/accept`
  - Deserialize response to ChatInviteModel
  - Return invitation

- [ ] T019 [US2] Create "Accept" button component in `frontend/lib/features/invitations/widgets/invitation_accept_button.dart`:
  - Only show for incoming invitations (type='incoming')
  - Green button with "Accept" label
  - Call acceptInvitation() on tap
  - Invalidate both pendingInvitesProvider and chatListProvider on success

- [ ] T020 [P] [US2] Update invitation list rendering in `InvitationsScreen` to show Accept/Decline buttons only for incoming

- [ ] T021 [US2] Manual test: Bob accepts Alice's invitation → verify:
  - Invitation status changes to 'accepted'
  - New chat appears in bob/alice chat lists
  - Accept button disappears

**Checkpoint**: User Stories 1 & 2 complete and independently testable

---

## Phase 5: User Story 3 - Recipient Rejects Invitation (Priority: P1)

**Goal**: Recipients can reject unwanted invitations

**Independent Test**: Bob rejects Alice's invitation → invitation disappears from Bob's pending, status shows "Rejected" in Alice's sent

### Implementation for User Story 3

- [ ] T022 [P] [US3] Implement backend endpoint `POST /api/invites/{id}/decline` in `backend/lib/server.dart` with:
  - Validate invitation exists
  - Validate current user is receiver_id
  - Validate status = 'pending' (FR-007)
  - UPDATE invites SET status='rejected', responded_at=NOW()
  - No chat creation (unlike accept)
  - Return updated invitation DTO (SC-003: <2 seconds)

- [ ] T023 [P] [US3] Implement `declineInvitation(invitationId)` method in `frontend/lib/features/invitations/services/invite_api_service.dart`:
  - POST to `/api/invites/{invitationId}/decline`
  - Return invitation

- [ ] T024 [US3] Create "Decline" button component in `frontend/lib/features/invitations/widgets/invitation_decline_button.dart`:
  - Only show for incoming invitations
  - Red button with "Decline" label
  - Call declineInvitation() on tap
  - Invalidate pendingInvitesProvider on success (removes from Bob's pending)

- [ ] T025 [P] [US3] Add rejected invitations to allInvitesProvider display logic if history view desired (optional)

- [ ] T026 [US3] Manual test: Bob declines Alice's invitation → verify:
  - Invitation status changes to 'rejected'
  - Removed from Bob's pending list
  - Alice's sent list shows 'Rejected' status

**Checkpoint**: User Stories 1, 2, & 3 complete (MVP core features)

---

## Phase 6: User Story 4 - Cancel Sent Invitation (Priority: P2)

**Goal**: Senders can cancel pending invitations they regret sending

**Independent Test**: Alice cancels invitation to Bob → invitation disappears from Alice's sent, Bob's pending (SC-007: <3 seconds on refresh)

### Implementation for User Story 4

- [ ] T027 [P] [US4] Implement backend endpoint `DELETE /api/invites/{id}` or `POST /api/invites/{id}/cancel` in `backend/lib/server.dart` with:
  - Validate invitation exists
  - Validate current user is sender_id
  - Validate status = 'pending' (FR-004)
  - UPDATE invites SET status='canceled', canceled_at=NOW()
  - Return updated invitation DTO

- [ ] T028 [P] [US4] Implement `cancelInvitation(invitationId)` method in `frontend/lib/features/invitations/services/invite_api_service.dart`:
  - DELETE to `/api/invites/{invitationId}` or POST cancel
  - Return invitation

- [ ] T029 [US4] Create "Cancel" button component in `frontend/lib/features/invitations/widgets/invitation_cancel_button.dart`:
  - Only show for outgoing invitations (type='outgoing') with status='pending'
  - Gray button with "Cancel" label
  - Call cancelInvitation() on tap
  - Invalidate sentInvitesProvider on success

- [ ] T030 [P] [US4] Update sent invitations rendering to show Cancel button conditionally

- [ ] T031 [US4] Manual test: Alice cancels invitation to Bob → verify:
  - Removed from Alice's sent list
  - Removed from Bob's pending list (on refresh)
  - Status is 'canceled'

**Checkpoint**: User Stories 1-4 complete; all core workflows functional

---

## Phase 7: User Story 5 - View Pending and Received Invitations (Priority: P2)

**Goal**: Users can see all pending invitations they received with full information

**Independent Test**: Bob has 3 pending invitations → all 3 displayed in inbox with senderName, createdAt (FR-008, FR-012)

### Implementation for User Story 5

- [ ] T032 [P] [US5] Implement backend endpoint `GET /api/users/{userId}/invites/pending` in `backend/lib/server.dart` with:
  - Validate user is authenticated
  - Validate requesting userId matches path userId (authorization)
  - Query: SELECT * FROM invites WHERE receiver_id = userId AND status = 'pending' ORDER BY created_at DESC
  - Include sender denormalized fields in response (senderName, senderAvatarUrl)
  - Return array of invitation DTOs (SC-002: <5 seconds)

- [ ] T033 [P] [US5] Implement `getPendingInvites()` in `InviteApiService` in `frontend/lib/features/invitations/services/invite_api_service.dart`:
  - GET from `/api/users/{userId}/invites/pending`
  - Parse response to List<ChatInviteModel>
  - Return list

- [ ] T034 [P] [US5] Create `PendingInvitesList` widget in `frontend/lib/features/invitations/widgets/pending_invites_list.dart`:
  - Display pending invitations chronologically (newest first)
  - Show senderName, senderAvatarUrl, createdAt
  - Show Accept/Decline buttons for each
  - Empty state message if no pending

- [ ] T035 [US5] Update `InvitationsScreen` to include PendingInvitesList section

- [ ] T036 [US5] Manual test: Bob views invitations screen → sees multiple pending invitations with correct details

**Checkpoint**: User Stories 1-5 complete

---

## Phase 8: User Story 6 - View Sent Invitations (Priority: P2)

**Goal**: Users can see all invitations they sent with current status

**Independent Test**: Alice sent 5 invitations (2 pending, 1 accepted, 1 rejected, 1 canceled) → all 5 displayed with correct status (FR-009)

### Implementation for User Story 6

- [ ] T037 [P] [US6] Implement backend endpoint `GET /api/users/{userId}/invites/sent` in `backend/lib/server.dart` with:
  - Validate user is authenticated
  - Validate requesting userId matches path userId (authorization)
  - Query: SELECT * FROM invites WHERE sender_id = userId ORDER BY created_at DESC
  - Include recipient denormalized fields (recipientName, recipientAvatarUrl)
  - Optional: filter by status if query param provided
  - Return array of invitation DTOs

- [ ] T038 [P] [US6] Implement `getSentInvites()` in `InviteApiService` in `frontend/lib/features/invitations/services/invite_api_service.dart`:
  - GET from `/api/users/{userId}/invites/sent`
  - Parse response to List<ChatInviteModel>
  - Return list

- [ ] T039 [P] [US6] Create `SentInvitesList` widget in `frontend/lib/features/invitations/widgets/sent_invites_list.dart`:
  - Display sent invitations chronologically
  - Show recipientName, recipientAvatarUrl, status, createdAt
  - Show Cancel button for 'pending' status only
  - Show read-only status badges for accepted/rejected/canceled

- [ ] T040 [US6] Update `InvitationsScreen` to include SentInvitesList section

- [ ] T041 [US6] Manual test: Alice views sent invitations → sees all sent with correct statuses and cancel buttons

**Checkpoint**: User Stories 1-6 all complete and fully functional

---

## Phase 9: Cross-Cutting Concerns & Polish

**Purpose**: Validation, error handling, testing, documentation

### Error Handling & Validation

- [ ] T042 [P] Implement comprehensive error handling in all backend endpoints:
  - Return appropriate HTTP status codes (400, 401, 403, 404, 409)
  - Include error codes and human-readable messages in responses
  - Log all errors with request context for debugging

- [ ] T043 [P] Add client-side error handling in `InviteApiService`:
  - Catch HTTP exceptions
  - Return meaningful error objects to UI
  - Provide user-friendly error messages

- [ ] T044 [P] Add validation and constraints in backend:
  - Self-invitation prevention (T011 verify, T042 error handling)
  - Duplicate pending invitation prevention (T011 verify, T042 error handling)
  - Status transition validation (only specific transitions allowed)
  - Timestamp validation (no future timestamps, responded_at ≥ created_at)

### Tests (Three-Tier: Unit, Widget, Integration)

- [ ] T045 [P] Unit tests for `ChatInviteModel` in `frontend/test/features/invitations/models/chat_invite_model_test.dart`:
  - JSON deserialization
  - Field validation
  - Enum status parsing

- [ ] T046 [P] Unit tests for `InviteApiService` in `frontend/test/features/invitations/services/invite_api_service_test.dart`:
  - Mock HTTP client responses
  - Test each method (send, accept, decline, cancel, getPending, getSent)
  - Verify proper error handling

- [ ] T047 [P] Unit tests for Riverpod providers in `frontend/test/features/invitations/providers/invites_provider_test.dart`:
  - allInvitesProvider combines pending + sent
  - Cache invalidation on mutations
  - Error state propagation

- [ ] T048 [P] Widget tests for `InvitationsScreen` in `frontend/test/features/invitations/screens/invitations_screen_test.dart`:
  - Renders pending + sent lists
  - Accept/Decline/Cancel buttons visible when appropriate
  - Loading state display
  - Empty state display

- [ ] T049 [P] Widget tests for individual button components:
  - `invitation_accept_button_test.dart` - Accept button visible only for incoming
  - `invitation_decline_button_test.dart` - Decline button visible only for incoming
  - `invitation_cancel_button_test.dart` - Cancel button visible only for outgoing pending

- [ ] T050 Integration tests in `frontend/integration_test/invitations_flow_test.dart`:
  - **Scenario 1**: Alice sends → Bob views pending → Bob accepts → verify chat created
  - **Scenario 2**: Alice sends → Bob views pending → Bob declines → verify status changed
  - **Scenario 3**: Alice sends → Alice cancels → verify removed from both views
  - **Scenario 4**: Mutual invitations (both send to each) → both appear as separate records

- [ ] T051 [P] Backend integration tests (dart test) in `backend/test/invites_test.dart`:
  - Create invitation succeeds with valid data
  - Duplicate pending returns 409 conflict
  - Self-invitation returns 400 error
  - Accept/Decline/Cancel endpoints work correctly
  - Authorization enforced (401 for missing token, 403 for non-owner)
  - Database state consistency verified

### Data Consistency & Edge Cases

- [ ] T052 Implement 30-day auto-deletion for rejected invitations (Q3):
  - Create background job trigger in backend
  - Query: DELETE FROM invites WHERE status='rejected' AND responded_at < NOW() - INTERVAL '30 days'
  - Document job scheduling (cron or batch system)
  - Add configuration for retention period

- [ ] T053 Verify race condition handling (Q2: timestamp-based):
  - Document that database transaction order determines winner
  - Verify: Accept + Cancel concurrent = first to commit wins
  - Test scenario in integration tests

- [ ] T054 Verify blocking respected (edge case):
  - Prevent sending invitation if receiver has blocked sender
  - Prevent accepting invitation if recipient has blocked sender
  - Return appropriate error message

### Documentation & Deployment

- [ ] T055 [P] Update README.md in `frontend/` and `backend/`:
  - Document new invitations feature
  - API endpoints listed
  - Testing instructions

- [ ] T056 [P] Update API documentation in `backend/API_REFERENCE.md` or similar:
  - Document all 6 endpoints
  - Request/response examples
  - Error codes
  - Rate limits

- [ ] T057 Create feature testing guide in `INVITE_TESTING_GUIDE.md`:
  - Manual testing procedures
  - Test scenarios (happy path, error cases)
  - Expected results

- [ ] T058 [P] Database migration verification script:
  - Verify schema, indexes, constraints in place
  - Can be run before feature deployment

- [ ] T059 Rebuild and deploy Docker containers:
  - `docker-compose down`
  - `docker-compose build --no-cache serverpod`
  - `docker-compose up -d`
  - Verify backend health endpoint returns 200 OK

- [ ] T060 Build Android APK for reviewer testing:
  - `flutter build apk --target-platform=android-arm64`
  - Verify APK builds without errors
  - Document location of APK artifact

### Final Verification

- [ ] T061 Constitution Check post-implementation:
  - Verify Principle I (Security) - all endpoints validate authorization
  - Verify Principle II (Architecture) - layer boundaries maintained
  - Verify Principle III (Testing) - three-tier tests all pass
  - Verify Principle IV (Code Consistency) - naming standards followed
  - Verify Principle V (Delivery) - docker-compose up succeeds

- [ ] T062 Code review preparation:
  - Run linter: `dart analyze` (backend) + `flutter analyze` (frontend)
  - Run formatters: `dart format`
  - Ensure no warnings
  - Generate code coverage report

- [ ] T063 Performance verification:
  - Send invitation: <2 seconds (SC-001) ✓
  - Pending invitations display: <5 seconds (SC-002) ✓
  - Accept/Reject/Cancel: <2 seconds (SC-003) ✓
  - Concurrent 100+ invitations: No data loss ✓
  - Status propagation: 95% within 5 seconds ✓

---

## Dependencies & Execution Order

### Critical Path (Must Execute in Order)

```
T001-T004 (Setup)
    ↓
T005-T010 (Foundation) - BLOCKS ALL user story work
    ↓
    ├─ T011-T016 (US1: Send) ──┐
    ├─ T017-T021 (US2: Accept) │ Can run in parallel
    ├─ T022-T026 (US3: Reject) │ after foundation
    ├─ T027-T031 (US4: Cancel) │
    ├─ T032-T036 (US5: Pending)│
    ├─ T037-T041 (US6: Sent)   │
    └─ T042-T051 (Testing)     │ Can run in parallel
        ↓
    T052-T062 (Polish & Verification)
```

### Parallel Opportunities

After Foundation (T005-T010) complete:
- **Backend endpoints**: T011, T017, T022, T027, T032, T037 can run in parallel (different endpoints)
- **Frontend services/models**: T012, T018, T023, T028, T033, T038 can run in parallel (different methods)
- **UI components**: T014, T019, T024, T029, T034, T039 can run in parallel (different widgets)
- **Tests**: T045-T051 can run in parallel (different test files)

### Sequential Dependencies

- T013 depends on T012 (model must exist)
- T015 depends on T013 (screen must exist)
- T020 depends on T019 (button must exist)
- T035 depends on T034 (widget must exist)
- T040 depends on T039 (widget must exist)
- T059 depends on all implementation (T011-T061)
- T061 depends on all tests passing (T045-T051)

---

## Effort Estimates per User Story

| Story | Phase | Backend Tasks | Frontend Tasks | Test Tasks | Estimate |
|-------|-------|---------------|----------------|-----------|----------|
| US1 (Send) | 3 | 1 | 3 | 1 | 1 day |
| US2 (Accept) | 4 | 1 | 2 | 1 | 1 day |
| US3 (Reject) | 5 | 1 | 2 | 1 | 1 day |
| US4 (Cancel) | 6 | 1 | 2 | 1 | 1 day |
| US5 (View Pend) | 7 | 1 | 2 | 1 | 0.5 day |
| US6 (View Sent) | 8 | 1 | 2 | 1 | 0.5 day |
| Foundation | 2 | 3 | 2 | 0 | 0.5 day |
| Testing | 9 | 0 | 0 | 7 | 1.5 days |
| Polish | 9 | 0 | 0 | 2 | 0.5 days |
| **TOTAL** | | **9** | **15** | **14** | **~7 days** |

---

## Success Criteria Verification

Before marking feature complete, verify:

- [ ] SC-001: Send invitation + display in sent list within 2 seconds ✓ (T016, T026 tests)
- [ ] SC-002: Pending invitations visible within 5 seconds of send ✓ (T036 tests)
- [ ] SC-003: Accept/Reject/Cancel complete within 2 seconds ✓ (T026, T031, T041 tests)
- [ ] SC-004: Duplicate prevention with clear error ✓ (T042-T044, T051)
- [ ] SC-005: 100+ concurrent invitations without data loss ✓ (T051 integration tests)
- [ ] SC-006: 95% state propagation within 5 seconds ✓ (T050-T051)
- [ ] SC-007: Canceled invitations disappear <3s on refresh ✓ (T050)
- [ ] SC-008: Full invitation history accessible ✓ (T040, T050)

---

## Sign-Off

**Phase 1 Status**: ✅ PLANNING COMPLETE

This task list is comprehensive, dependency-ordered, and ready for execution. Each user story can be implemented independently after the foundation phase. Use this list to track progress and ensure all requirements are met.

**Next Step**: Begin Phase 3 (User Story 1) implementation using this task list and quickstart.md as guidance.
