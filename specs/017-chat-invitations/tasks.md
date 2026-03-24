# Implementation Tasks: Chat Invitations

**Feature**: 017-chat-invitations | **Date**: 2026-03-15  
**Status**: Ready for Implementation | **Total Tasks**: 60+

---

## Overview

This document defines all actionable tasks for implementing the Chat Invitations feature. Tasks are organized by user story in priority order, with independent test criteria for each story. MVP scope: Complete User Stories 1-3 (Send, View, Accept). User Story 4 (Decline) is P2 polish.

**Dependency Flow**: All stories depend on completion of Phase 1 (Foundational setup). Stories can be implemented in parallel once foundational tasks complete.

---

## Phase 1: Setup & Foundational Infrastructure

### Foundational Setup (Non-parallelizable - blocking all stories)

- [x] T001 Initialize database migration file structure in `backend/migrations/006_create_invites_table.dart`
- [x] T002 Create Serverpod ChatInvite data model in `backend/lib/src/models/chat_invite.dart` with freezed annotations
- [x] T003 Create Frontend ChatInviteModel with freezed in `frontend/lib/features/invitations/models/chat_invite_model.dart`
- [x] T004 Create InviteApiService stub in `frontend/lib/features/invitations/services/invite_api_service.dart` with method signatures
- [x] T005 Create base Riverpod providers in `frontend/lib/features/invitations/providers/invites_provider.dart` (structure only)
- [x] T006 Add Invitations tab to main navigation bar in `frontend/lib/shared/navigation/main_navigation.dart`
- [x] T007 Create InvitationsScreen stub in `frontend/lib/features/invitations/screens/invitations_screen.dart` with tab layout

**Independent Test Criteria (Phase 1)**:
- ✅ Database migration runs without errors
- ✅ Serverpod model compiles and serializes/deserializes correctly
- ✅ Frontend models compile with freezed code generation
- ✅ API service has required method signatures
- ✅ Invitations tab appears in main navigation
- ✅ InvitationsScreen displays with empty pending/sent lists

---

## Phase 2: User Story 1 - Send Chat Invitation (Priority: P1)

### Backend Implementation (Send Invite)

- [x] T008 Implement database migration: Create chat_invites table with indexes in `backend/migrations/006_create_invites_table.dart`
  - Schema: id (UUID), sender_id, recipient_id, status, created_at, updated_at, deleted_at
  - Indexes: (recipient_id, status), (sender_id, status)
  - Constraints: sender != recipient, unique(sender, recipient) WHERE status='pending'

- [x] T009 [P] Implement InviteService.sendInvite() in `backend/lib/src/services/invite_service.dart`
  - Validation: Check sender != recipient (FR-001)
  - Validation: Check users already chatting (FR-002)
  - Validation: Check duplicate pending invite
  - Create ChatInvite record (FR-003)
  - Return created invite with sender/recipient metadata

- [x] T010 [P] Implement InviteService.getPendingInvites() in `backend/lib/src/services/invite_service.dart`
  - Query: recipient_id + status='pending', order by created_at DESC
  - Include sender metadata (name, avatar)
  - Return list of ChatInvite

- [x] T011 [P] Implement sendInvite endpoint in `backend/lib/src/endpoints/invites_endpoint.dart`
  - Method: POST /api/invites/send
  - Input: recipientId
  - Auth: Require JWT token, extract userId from auth context
  - Response: ChatInvite object (HTTP 201)
  - Error handling: 400 (validation), 401 (auth), 404 (user not found), 409 (duplicate)

- [ ] T012 [P] Write InviteService unit tests in `backend/test/services/invite_service_test.dart`
  - Test: sendInvite creates valid ChatInvite record
  - Test: sendInvite rejects self-invites with 400 error
  - Test: sendInvite rejects if already chatting
  - Test: sendInvite rejects duplicate pending invites with 409 error
  - Test: getPendingInvites returns correct records sorted by created_at DESC

- [ ] T013 [P] Write invites endpoint integration tests in `backend/test/endpoints/invites_endpoint_test.dart`
  - Test: POST /invites/send creates invite successfully
  - Test: POST /invites/send returns 401 without JWT token
  - Test: POST /invites/send returns 400 for validation errors
  - Test: Multiple concurrent sends don't create duplicate invites

### Frontend Implementation (Send Invite)

- [x] T014 [P] Create SendInvitePickerScreen in `frontend/lib/features/invitations/screens/send_invite_picker_screen.dart`
  - UI: User discovery/search interface (search field, user list with avatars/names)
  - Button: "Send Invite" with disabled state if no user selected or already contacts
  - Navigation: From Invitations tab "Send New" button
  - State: Display loading, error, and success states

- [x] T015 [P] Implement InviteApiService.sendInvite() in `frontend/lib/features/invitations/services/invite_api_service.dart`
  - HTTP POST to /api/invites/send with recipientId
  - Parse response to ChatInvite model
  - Handle error responses (409, 400) with appropriate exceptions

- [ ] T016 [P] Create SendInviteMutationProvider in `frontend/lib/features/invitations/providers/send_invite_provider.dart`
  - StateNotifier with states: initial, loading, success, error
  - Method: sendInvite(String recipientId)
  - Side effects: Invalidate sentInvitesProvider on success
  - Show confirmation toast on success

- [x] T017 [P] Integrate SendInvitePickerScreen into InvitationsScreen in `frontend/lib/features/invitations/screens/invitations_screen.dart`
  - Add "Send New Invite" button to header
  - Navigate to SendInvitePickerScreen on tap
  - Handle success: refresh sent invites list, return to InvitationsScreen

- [ ] T018 [P] Write SendInvitePickerScreen widget tests in `frontend/test/widget/send_invite_picker_test.dart`
  - Test: Screen displays user list
  - Test: Send button is disabled when no user selected
  - Test: Tapping send button calls sendInvite mutation
  - Test: Success/error states display correctly

- [ ] T019 [P] Write InviteApiService unit tests in `frontend/test/services/invite_api_service_test.dart`
  - Test: sendInvite makes correct HTTP request
  - Test: sendInvite parses response to ChatInvite model
  - Test: sendInvite throws exception on 409 error (duplicate)
  - Test: sendInvite throws exception on 400 error (validation)

- [ ] T020 [P] Write SendInviteMutationProvider tests in `frontend/test/providers/send_invite_provider_test.dart`
  - Test: sendInvite transitions through loading/success/error states
  - Test: sentInvitesProvider invalidated on success
  - Test: Error states display error message

**Independent Test Criteria (User Story 1 - Send Invite)**:
- ✅ Backend: Send invite endpoint creates ChatInvite and rejects duplicates
- ✅ Backend: Validation prevents self-invites and invites to existing contacts
- ✅ Frontend: User can select another user and tap "Send Invite"
- ✅ Frontend: Success confirmation shows; sent invite appears in "Sent" tab
- ✅ Frontend: Error messages display for validation failures (duplicate, already chatting)
- ✅ All backend unit + endpoint tests pass
- ✅ All frontend widget + service tests pass
- ✅ 2-user test: User A sends invite to User B successfully

---

## Phase 3: User Story 2 - View Pending Invitations (Priority: P1)

### Backend Implementation (Get Pending Invites)

- [x] T021 Implement getPendingInvites endpoint in `backend/lib/src/endpoints/invites_endpoint.dart`
  - Method: GET /api/invites/pending
  - Auth: Require JWT token
  - Query params: limit (default 50), offset (default 0)
  - Response: List of ChatInvite with sender metadata, total count
  - Implementation: Call InviteService.getPendingInvites()

- [ ] T022 [P] Write getPendingInvites endpoint tests in `backend/test/endpoints/invites_endpoint_test.dart`
  - Test: GET /invites/pending returns pending invites for recipient
  - Test: Results ordered by created_at DESC
  - Test: Returns 401 without JWT token
  - Test: Empty list returned if no pending invites
  - Test: Pagination works correctly (limit/offset)

### Frontend Implementation (View Pending Invites)

- [x] T023 [P] Implement PendingInvitesProvider in `frontend/lib/features/invitations/providers/invites_provider.dart`
  - FutureProvider that calls InviteApiService.fetchPendingInvites()
  - Handles loading, data, and error states
  - Auto-refresh when mutations succeed (accept/decline)

- [x] T024 [P] Implement InviteCountProvider in `frontend/lib/features/invitations/providers/invites_provider.dart`
  - FutureProvider that returns count of pending invites
  - Used for badge on Invitations tab

- [x] T025 [P] Update InvitationsScreen "Pending Invitations" tab in `frontend/lib/features/invitations/screens/invitations_screen.dart`
  - Display: List of pending invites with sender avatar, name, timestamp
  - Empty state: "You have no pending invites" message
  - Unread indicator: Visual distinction for unread invites
  - Actions: Accept and Decline buttons visible per invite

- [x] T026 [P] Update InvitationsScreen tab badge in `frontend/lib/features/invitations/screens/invitations_screen.dart`
  - Display: Badge showing count of pending invites
  - Update: Badge refreshes when new invites received
  - Icon: Envelope or mail icon

- [x] T027 [P] Update InviteApiService.fetchPendingInvites() in `frontend/lib/features/invitations/services/invite_api_service.dart`
  - HTTP GET to /api/invites/pending
  - Parse response list to ChatInvite models
  - Handle errors (401, 500)

- [ ] T028 [P] Write InvitationsScreen pending view tests in `frontend/test/widget/invitations_screen_test.dart`
  - Test: Pending tab displays list of invites
  - Test: Empty state shows when no pending invites
  - Test: Badge count displays correctly
  - Test: Sender info (name, avatar) displays
  - Test: Accept/Decline buttons visible and tappable

- [ ] T029 [P] Write PendingInvitesProvider tests in `frontend/test/providers/invites_provider_test.dart`
  - Test: Provider fetches pending invites on initial load
  - Test: Provider refreshes data on manual refresh
  - Test: Provider handles API errors gracefully
  - Test: Auto-refresh works after accept/decline mutations

**Independent Test Criteria (User Story 2 - View Pending)**:
- ✅ Backend: GET /invites/pending returns correct pending invites for user
- ✅ Backend: Results sorted by created_at DESC with proper pagination
- ✅ Frontend: Invitations tab displays pending invites list
- ✅ Frontend: Badge shows unread count on tab
- ✅ Frontend: Empty state displays when no pending invites
- ✅ All backend pagination tests pass
- ✅ All frontend provider + widget tests pass

---

## Phase 4: User Story 3 - Accept Chat Invitation (Priority: P1)

### Backend Implementation (Accept Invite)

- [x] T030 Implement InviteService.acceptInvite() in `backend/lib/src/services/invite_service.dart`
  - Validation: Check invite exists and is pending
  - Validation: Check current user is recipient
  - Update invite: status → 'accepted', deleted_at set
  - Create Chat: Insert new chat with sender/recipient as participants
  - Cleanup: Remove any mutual pending invites between same users
  - Return: (invite, chat) tuple

- [x] T031 [P] Implement acceptInvite endpoint in `backend/lib/src/endpoints/invites_endpoint.dart`
  - Method: POST /api/invites/{inviteId}/accept
  - Path param: inviteId (UUID)
  - Auth: Require JWT token, check isRecipient
  - Response: ChatInvite + Chat object (HTTP 200)
  - Error handling: 400 (not pending), 403 (not recipient), 404 (not found)

- [ ] T032 [P] Write acceptInvite service unit tests in `backend/test/services/invite_service_test.dart`
  - Test: acceptInvite creates chat with both participants
  - Test: acceptInvite marks invite as accepted and deleted_at set
  - Test: acceptInvite removes mutual pending invites
  - Test: acceptInvite rejects if not pending (400 error)
  - Test: acceptInvite rejects if user not recipient (403 error)

- [ ] T033 [P] Write acceptInvite endpoint integration tests in `backend/test/endpoints/invites_endpoint_test.dart`
  - Test: POST /invites/{id}/accept creates chat and updates invite
  - Test: New chat appears in recipient's chat list
  - Test: Returns 403 if current user not recipient
  - Test: Returns 400 if invite not pending
  - Test: Mutual pending invites removed after accept

### Frontend Implementation (Accept Invite)

- [ ] T034 [P] Create AcceptInviteMutationProvider in `frontend/lib/features/invitations/providers/accept_invite_provider.dart`
  - StateNotifier with states: initial, loading, success, error
  - Method: acceptInvite(String inviteId)
  - Side effects: Invalidate pendingInvitesProvider on success
  - Side effects: Trigger navigation to new chat or refresh chat list

- [x] T035 [P] Implement InviteApiService.acceptInvite() in `frontend/lib/features/invitations/services/invite_api_service.dart`
  - HTTP POST to /api/invites/{inviteId}/accept
  - Parse response to (ChatInvite, Chat) models
  - Handle errors (403, 400, 404)

- [x] T036 [P] Add Accept button handler to InvitationsScreen in `frontend/lib/features/invitations/screens/invitations_screen.dart`
  - Button: Accept button on each pending invite card
  - Action: Call acceptInvite mutation on tap
  - Loading: Show loading indicator on button during request
  - Success: Refresh pending list, optionally navigate to new chat
  - Error: Show error dialog with message

- [ ] T037 [P] Write acceptInvite mutation tests in `frontend/test/providers/accept_invite_provider_test.dart`
  - Test: acceptInvite transitions through loading/success states
  - Test: pendingInvitesProvider invalidated on success
  - Test: Error states display error message
  - Test: Chat list updated after acceptance

- [ ] T038 [P] Write InvitationsScreen accept button tests in `frontend/test/widget/invitations_screen_test.dart`
  - Test: Tapping Accept button calls acceptInvite mutation
  - Test: Loading indicator shows during accept operation
  - Test: Success: Invite removed from pending list
  - Test: Error dialog shows on failure
  - Test: New chat appears in chat list after accept

**Independent Test Criteria (User Story 3 - Accept Invite)**:
- ✅ Backend: Accept endpoint creates chat between sender/recipient
- ✅ Backend: Mutual pending invites removed after acceptance
- ✅ Backend: Returns 403 if user not recipient
- ✅ Backend: Returns 400 if invite not pending
- ✅ Frontend: Accept button visible on pending invites
- ✅ Frontend: Tapping Accept calls API and updates UI
- ✅ Frontend: Pending invite removed from list after acceptance
- ✅ Frontend: New chat appears in chat list
- ✅ All backend integration tests pass
- ✅ All frontend widget tests pass
- ✅ 2-user test: User A sends invite, User B accepts, chat appears for both

---

## Phase 5: User Story 4 - Decline Chat Invitation (Priority: P2)

### Backend Implementation (Decline Invite)

- [ ] T039 Implement InviteService.declineInvite() in `backend/lib/src/services/invite_service.dart`
  - Validation: Check invite exists and is pending
  - Validation: Check current user is recipient
  - Update invite: status → 'declined', deleted_at set
  - Return: Updated ChatInvite

- [x] T040 [P] Implement declineInvite endpoint in `backend/lib/src/endpoints/invites_endpoint.dart`
  - Method: POST /api/invites/{inviteId}/decline
  - Path param: inviteId (UUID)
  - Auth: Require JWT token, check isRecipient
  - Response: ChatInvite object (HTTP 200)
  - Error handling: 400 (not pending), 403 (not recipient), 404 (not found)

- [x] T041 [P] Write declineInvite service unit tests in `backend/test/services/invite_service_test.dart`
  - Test: declineInvite marks invite as declined and deleted_at set
  - Test: declineInvite rejects if not pending (400 error)
  - Test: declineInvite rejects if user not recipient (403 error)
  - Test: Declining doesn't block future invites from same sender

- [ ] T042 [P] Write declineInvite endpoint integration tests in `backend/test/endpoints/invites_endpoint_test.dart`
  - Test: POST /invites/{id}/decline updates invite status
  - Test: Returns 403 if current user not recipient
  - Test: Returns 400 if invite not pending
  - Test: Invite no longer appears in pending list after decline

### Frontend Implementation (Decline Invite)

- [ ] T043 [P] Create DeclineInviteMutationProvider in `frontend/lib/features/invitations/providers/decline_invite_provider.dart`
  - StateNotifier with states: initial, loading, success, error
  - Method: declineInvite(String inviteId)
  - Side effects: Invalidate pendingInvitesProvider on success

- [x] T044 [P] Implement InviteApiService.declineInvite() in `frontend/lib/features/invitations/services/invite_api_service.dart`
  - HTTP POST to /api/invites/{inviteId}/decline
  - Parse response to ChatInvite model
  - Handle errors (403, 400, 404)

- [x] T045 [P] Add Decline button handler to InvitationsScreen in `frontend/lib/features/invitations/screens/invitations_screen.dart`
  - Button: Decline button on each pending invite card
  - Action: Call declineInvite mutation on tap
  - Loading: Show loading indicator during request
  - Success: Refresh pending list, remove invite from display
  - Error: Show error dialog

- [ ] T046 [P] Write declineInvite mutation tests in `frontend/test/providers/decline_invite_provider_test.dart`
  - Test: declineInvite transitions through loading/success states
  - Test: pendingInvitesProvider invalidated on success
  - Test: Error states display error message

- [ ] T047 [P] Write InvitationsScreen decline button tests in `frontend/test/widget/invitations_screen_test.dart`
  - Test: Tapping Decline button calls declineInvite mutation
  - Test: Loading indicator shows during operation
  - Test: Success: Invite removed from pending list
  - Test: Error dialog shows on failure

**Independent Test Criteria (User Story 4 - Decline Invite)**:
- ✅ Backend: Decline endpoint marks invite as declined
- ✅ Backend: Returns 403 if user not recipient
- ✅ Backend: Returns 400 if invite not pending
- ✅ Frontend: Decline button visible on pending invites
- ✅ Frontend: Tapping Decline removes invite from list
- ✅ All backend tests pass
- ✅ All frontend tests pass

---

## Phase 6: Cross-Cutting Concerns & Polish

### Push Notifications Integration

- [ ] T048 Integrate Firebase Cloud Messaging (FCM) for push notifications in backend
  - Send push to recipient when invite created
  - Payload: sender name, "New chat invitation from {senderName}"
  - Deep link: messenger://invitations?tab=pending

- [ ] T049 [P] Handle push notification tap in frontend `frontend/lib/core/push_notifications/push_notification_handler.dart`
  - Route to InvitationsScreen when invite notification tapped
  - Set tab to "Pending" automatically

- [ ] T050 [P] Write push notification integration tests
  - Test: Push notification sent when invite created
  - Test: Deep link routes to InvitationsScreen
  - Test: Badge updated when push received

### View Sent Invitations (Supporting)

- [ ] T051 Implement getSentInvites endpoint in `backend/lib/src/endpoints/invites_endpoint.dart`
  - Method: GET /api/invites/sent
  - Return: List of sent invites by current user, sorted by created_at DESC

- [ ] T052 [P] Implement InviteApiService.fetchSentInvites() in frontend
  - HTTP GET to /api/invites/sent
  - Parse response to ChatInvite list

- [ ] T053 [P] Update InvitationsScreen "Sent Invitations" tab
  - Display list of invites sent by user
  - Show recipient name, status, timestamp
  - No action buttons (read-only status view)

- [ ] T054 [P] Create SentInvitesProvider in `frontend/lib/features/invitations/providers/invites_provider.dart`
  - FutureProvider that fetches sent invites
  - Invalidate on sendInvite success

### Error Handling & User Feedback

- [ ] T055 [P] Implement error message mapping in `frontend/lib/features/invitations/services/invite_error_handler.dart`
  - Map backend error codes to user-friendly messages
  - Handle network errors, validation errors, server errors
  - Log errors for debugging

- [ ] T056 [P] Add error dialogs to all mutation endpoints in InvitationsScreen
  - Display friendly error messages on operation failures
  - Retry button for network errors
  - Dismiss button to close dialogs

- [ ] T057 [P] Implement validation feedback in SendInvitePickerScreen
  - Disable Send button if user already contacted
  - Show message: "You're already chatting with this user"
  - Check validity before showing picker

### Offline Support

- [ ] T058 [P] Implement local caching of invites in `frontend/lib/features/invitations/services/invite_cache_service.dart`
  - Cache pending/sent invites in local storage (shared_preferences or drift)
  - Display cached data when offline
  - Disable action buttons (accept/decline/send) offline

- [ ] T059 [P] Implement action queue for offline mutations in `frontend/lib/features/invitations/providers/offline_queue_provider.dart`
  - Queue accept/decline/send actions when offline
  - Retry queued actions when online
  - Show "Pending sync" indicator

- [ ] T060 [P] Write offline tests in `frontend/test/providers/offline_sync_test.dart`
  - Test: Cached data displays when offline
  - Test: Actions queued and executed after reconnect
  - Test: Queued actions have retry logic

### Performance & Scaling

- [ ] T061 [P] Implement pagination for large invite lists in `frontend/lib/features/invitations/screens/invitations_screen.dart`
  - Lazy load invites as user scrolls
  - Load 50 at a time, fetch next batch at 80% scroll

- [ ] T062 [P] Add database indexes verification in `backend/migrations/006_create_invites_table.dart`
  - Verify (recipient_id, status) index for fast pending lookups
  - Verify (sender_id, status) index for fast sent lookups
  - Performance test: <100ms for 10k invites query

### Documentation & Handoff

- [ ] T063 Update API documentation in `specs/017-chat-invitations/contracts/invite_api.yaml`
  - Verify all endpoints match implementation
  - Add response examples
  - Document all error codes

- [ ] T064 [P] Create developer README in `backend/README.md` - Invitations section
  - How to run migrations
  - How to test endpoints locally
  - Common troubleshooting

- [ ] T065 [P] Create frontend integration guide in `frontend/README.md` - Invitations section
  - How to test InvitationsScreen
  - How to test 2-user invite flow
  - Testing on emulator

### Integration Testing (End-to-End)

- [ ] T066 [P] Write 2-user invite flow integration test
  - User A sends invite to User B
  - Verify invite appears in User B's pending list
  - User B accepts
  - Verify chat created for both users
  - Verify invites auto-cleaned up

- [ ] T067 [P] Write mutual invite scenario test
  - User A sends invite to User B
  - User B sends invite to User A (simultaneously)
  - User A accepts
  - Verify chat created, mutual invite cleaned
  - Verify User B can see no duplicate

- [ ] T068 [P] Write edge case tests
  - Self-invite rejection
  - Duplicate duplicate prevention
  - Invite to existing contact rejection
  - Offline accept (queued, then executed)

### QA & Testing

- [ ] T069 Test all user stories manually on Android emulator
  - Story 1: Send invite successfully
  - Story 2: View pending invites with badge
  - Story 3: Accept invite, create chat
  - Story 4: Decline invite, reject correctly

- [ ] T070 Test all user stories manually on iOS simulator
  - Same flows as Android
  - Verify iOS-specific navigation/gestures

- [ ] T071 Performance testing
  - Send 100+ invites, verify no slowdown
  - Accept 100+ invites, verify <1s per operation
  - Load 10k+ pending invites, verify pagination works

- [ ] T072 Security testing
  - Verify JWT validation on all endpoints
  - Verify user can't access others' invites
  - Verify rate limiting not bypassed

- [ ] T073 Build release APK and test
  - `flutter build apk --release`
  - Test on physical Android device
  - Verify all features work

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)
**Timeline**: 8-10 days

**Phase 1 (1 day)**: Setup + foundational infrastructure (T001-T007)  
**Phase 2 (2-3 days)**: Send invite (T008-T020)  
**Phase 3 (2-3 days)**: View pending + Badge (T021-T029)  
**Phase 4 (2-3 days)**: Accept invite + Chat creation (T030-T038)  
**Phase 5 (1 day)**: Basic error handling + UI polish (T055-T056)  
**QA (1-2 days)**: Manual testing + fixes (T069-T072)  

**NOT in MVP**:
- Decline functionality (moves to Phase 5 - P2)
- Push notifications (moves to Phase 6)
- Offline support (moves to Phase 6)
- Sent invites tab (moves to Phase 6)

### Phase 2: Polish & Production Readiness (Days 11-15)
- Complete User Story 4 (Decline) - T039-T047
- Push notifications - T048-T050
- Error handling improvements - T055-T057
- Offline support - T058-T060
- Documentation - T063-T065
- Full integration testing - T066-T068

---

## Parallel Execution Examples

### Day 1-2 (Setup Phase)
**Parallel**: Backend + Frontend can setup simultaneously
- Backend team: T001-T002, T008 (migration + model)
- Frontend team: T003-T007 (models, services, screens)
- Testing team: Set up test infrastructure

### Day 3-4 (Send Invite - P)
**Parallel**: All parallelizable tasks ([P] marked) run in parallel
- Backend: T009, T010, T011, T012, T013
- Frontend: T014, T015, T016, T017, T018, T019, T020
- Testing: Backend endpoint tests + Frontend widget tests in parallel

### Day 5-6 (View Pending)
**Parallel**: T021-T029 all can run in parallel after Phase 1 complete
- Backend: T021-T022
- Frontend: T023-T028
- Testing: All provider + widget tests

### Day 7-8 (Accept Invite)
**Parallel**: T030-T038 all can run in parallel
- Backend: T030-T033
- Frontend: T034-T038
- Testing: Integration tests verify chat creation

---

## Dependency Graph

```
Phase 1 (Foundational) ✓
  ↓
  ├→ Phase 2 (Send Invite) ✓
  │   ↓
  │   ├→ Phase 3 (View Pending) ✓
  │   │
  │   ├→ [Parallel] Phase 4 (Accept) ✓
  │   │
  │   └→ [Parallel] Phase 5 (Decline) 
  │
  └→ Phase 6 (Polish & Cross-Cutting)
       ├→ Push Notifications
       ├→ Error Handling
       ├→ Offline Support
       ├→ Sent Invites Tab
       └→ Integration Testing

Alternative Path (Agile):
  Phase 1 → Phase 2 → Phase 4 (skip 3) → Phase 6
  (MVP: Send + Accept only, View via sent endpoint)
```

---

## Success Criteria

### Per-Story Completion
- ✅ All backend unit + integration tests passing
- ✅ All frontend widget + provider tests passing
- ✅ 2-user manual test scenario successful
- ✅ No console errors or warnings
- ✅ Code review approved

### Overall Completion (Full Feature)
- ✅ All 4 user stories complete and tested
- ✅ 60+ tasks completed
- ✅ 95%+ test coverage for services/providers
- ✅ Performance: <500ms send, <300ms accept, <1s load 100+ invites
- ✅ Push notifications delivered within 3 seconds
- ✅ Release APK built and tested on device
- ✅ Documentation complete
- ✅ Feature branch merged to main after approval

