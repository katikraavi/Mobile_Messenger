# Tasks: Core Database Models

**Input**: Design documents from `/specs/002-core-db-models/`  
**Prerequisites**: ✅ plan.md, spec.md, research.md, data-model.md, contracts/  
**Status**: Ready for Implementation  
**Branch**: `002-core-db-models`

**Note**: Tasks are organized by user story to enable independent implementation, testing, and delivery of each feature. Each phase must complete before the next begins, but tasks within a phase can run in parallel.

## Phase 1: Setup (Project & Migration Framework)

**Purpose**: Initialize backend project structure and Serverpod migration framework

- [ ] T001 Create backend/migrations/ directory for database migration files in Dart format
- [ ] T002 [P] Set up Serverpod server.dart configuration with PostgreSQL connection pooling in backend/lib/server.dart
- [ ] T003 [P] Create backend/lib/src/models/ directory structure for entity definitions
- [ ] T004 [P] Create backend/lib/src/services/ directory structure for data access layer
- [ ] T005 [P] Initialize test/unit/ and test/integration/ directories for database tests
- [ ] T006 Verify docker-compose.yml has PostgreSQL configured with messenger_db database
- [ ] T007 [P] Add required Dart dependencies to backend/pubspec.yaml: uuid (^1.0.0), cryptography (^2.7.0)

**Checkpoint**: Project structure ready, docker-compose backend operational

---

## Phase 2: Foundational - Database Infrastructure

**Purpose**: Establish core database schema, ENUMs, and constraints

**⚠️ CRITICAL**: This phase must complete before ANY user story implementation

- [ ] T008 Create backend/migrations/001_create_enums.dart with message_status and invite_status ENUM types
- [ ] T009 Create backend/migrations/002_create_users_table.dart with columns: id (UUID), email (UNIQUE), username (UNIQUE), password_hash, email_verified, profile_picture_url, about_me, created_at; indexes on email, username
- [ ] T010 [P] Create backend/migrations/003_create_chats_table.dart with columns: id (UUID), created_at, archived_by_users (UUID[] array); indexes on created_at
- [ ] T011 [P] Create backend/migrations/004_create_chat_members_table.dart with composite PK (user_id, chat_id), joined_at, left_at; foreign keys to User (CASCADE) and Chat (CASCADE); indexes on user_id, chat_id
- [ ] T012 [P] Create backend/migrations/005_create_messages_table.dart with columns: id (UUID), chat_id (FK→Chat CASCADE), sender_id (FK→User RESTRICT), encrypted_content (TEXT), media_url, media_type, status (message_status ENUM), created_at, edited_at; indexes on (chat_id, created_at DESC), sender_id, status
- [ ] T013 [P] Create backend/migrations/006_create_invites_table.dart with columns: id (UUID), sender_id (FK→User CASCADE), receiver_id (FK→User CASCADE), status (invite_status ENUM), created_at, responded_at; CHECK (sender_id != receiver_id); UNIQUE(sender_id, receiver_id, status) partial index for status='pending'; indexes on (receiver_id, status), (sender_id, created_at DESC)

**Checkpoint**: All 6 migrations execute successfully via `docker-compose up`, all tables created with proper constraints

---

## Phase 3: User Story 1 - User Registration & Profile Setup (Priority: P1)

**Goal**: Enable new users to create accounts with email/password and manage profiles. Ensure email and username uniqueness at database level.

**Independent Test**: (1) Create new user with email and password, (2) Verify record persists with correct fields, (3) Duplicate email registration fails, (4) User can log back in with credentials, (5) Profile fields (picture_url, about_me) updateable and retrievable

### Implementation for User Story 1

- [ ] T014 [P] Create backend/lib/src/models/user_model.dart with User class: id, email, username, password_hash, email_verified, profile_picture_url, about_me, created_at; include toJson/fromJson serialization
- [ ] T015 [P] Create backend/lib/src/models/enums.dart with MessageStatus and InviteStatus enum definitions (matching database ENUMs)
- [ ] T016 Create backend/lib/src/services/user_service.dart with methods: createUser(email, username, passwordHash), getUserById(id), getUserByEmail(email), getUserByUsername(username), updateUserProfile(userId, profilePictureUrl, aboutMe, emailVerified), getAllUsers(limit, offset)
- [ ] T017 [US1] Create backend/lib/src/endpoints/user_endpoints.dart with endpoints: POST /register (create user), POST /login (verify email+password), GET /user/:id (get profile), PUT /user/:id/profile (update profile), GET /user/email/:email (check availability)
- [ ] T018 [P] [US1] Create test/unit/test_user_model.dart with serialization tests for User model
- [ ] T019 [US1] Create test/integration/test_user_service.dart with tests: createUser success, duplicate email constraint violation, getUserById, getUserByEmail, updateUserProfile with email_verified flag
- [ ] T020 [P] [US1] Create test/integration/test_user_endpoints.dart with endpoint tests: register success, login with valid credentials, login with invalid credentials, duplicate email rejection, profile updates

**Checkpoint**: User Story 1 complete - users can register, log in, and access/update profiles independently

---

## Phase 4: User Story 2 - Chat Creation & Membership (Priority: P1)

**Goal**: Enable users to create one-on-one or group chats, adding members with proper membership tracking. Chats can be archived per-user without affecting other users.

**Independent Test**: (1) Create chat and verify created_at stored, (2) Add two users as members, (3) Query user's chats returns only active (non-left) memberships, (4) Archive chat for user, (5) User's active chat list excludes archived chats, (6) Other users still see chat as active

### Implementation for User Story 2

- [ ] T021 [P] Create backend/lib/src/models/chat_model.dart with Chat class: id, created_at, archivedByUserIds (List<String>); include toJson/fromJson
- [ ] T022 [P] Create backend/lib/src/models/chat_member_model.dart with ChatMember class: userId, chatId, joinedAt, leftAt; include toJson/fromJson and isActive computed property
- [ ] T023 Create backend/lib/src/services/chat_service.dart with methods: createChat(), addMember(chatId, userId), removeMember(chatId, userId, leftAt=NOW()), getChatById(id), getUserChats(userId, excludeArchived=true), archiveChat(chatId, userId), unarchiveChat(chatId, userId), getChatMembers(chatId, activeOnly=true)
- [ ] T024 [US2] Create backend/lib/src/endpoints/chat_endpoints.dart with endpoints: POST /chat (create), POST /chat/:id/members (add member), DELETE /chat/:id/members/:userId (remove), GET /chat/:id (get chat), GET /user/:userId/chats (user's chats), PUT /chat/:id/archive (archive), PUT /chat/:id/unarchive (unarchive)
- [ ] T025 [P] [US2] Create test/unit/test_chat_model.dart with serialization and archived_by_users array handling tests
- [ ] T026 [P] [US2] Create test/unit/test_chat_member_model.dart with isActive computation tests
- [ ] T027 [US2] Create test/integration/test_chat_service.dart with tests: createChat, addMember creates ChatMember record, removeMember sets left_at, getChatMembers returns active members only, archiveChat updates archived_by_users array, getUserChats excludes archived chats
- [ ] T028 [P] [US2] Create test/integration/test_chat_endpoints.dart with endpoint tests: create chat, add member, remove member, get active chats for user, archive/unarchive operations, verify cascade delete behavior

**Checkpoint**: User Story 2 complete - users can create chats, manage membership, and archive independently per-user

---

## Phase 5: User Story 3 - Message Sending & Status Tracking (Priority: P1)

**Goal**: Enable users to send encrypted messages with media support and track delivery/read status. Messages support editing with timestamp tracking.

**Independent Test**: (1) Send text message to chat, verify stored with sender_id, encrypted_content, status='sent', created_at, (2) Send message with media attachment, verify media_url and media_type stored, (3) Update message status: sent → delivered → read, (4) Edit message, verify edited_at timestamp recorded and content updated, (5) Query messages in chat with pagination (most recent first)

### Implementation for User Story 3

- [ ] T029 [P] Create backend/lib/src/models/message_model.dart with Message class: id, chatId, senderId, encryptedContent, mediaUrl, mediaType, status (MessageStatus enum), createdAt, editedAt; include toJson/fromJson and isEdited computed property
- [ ] T030 Create backend/lib/src/services/message_service.dart with methods: createMessage(chatId, senderId, encryptedContent, mediaUrl?, mediaType?), getMessagesByChatId(chatId, limit=50, offset=0, orderBy=createdAt DESC), updateMessageStatus(messageId, status), editMessage(messageId, senderId, newEncryptedContent), deleteMessage(messageId), getMessagesByStatus(status, createdAt > ?), getUnreadMessageCount(userId)
- [ ] T031 [P] Create backend/lib/src/services/encryption_service.dart with methods: encryptMessage(plaintext, symmetricKey) → encryptedContent as TEXT, decryptMessage(encryptedContent, symmetricKey) → plaintext using cryptography package AES-256-GCM; include key management best practices (no logging of keys)
- [ ] T032 [US3] Create backend/lib/src/endpoints/message_endpoints.dart with endpoints: POST /chat/:chatId/messages (create), GET /chat/:chatId/messages (paginated list), PUT /messages/:id/status (update status), PUT /messages/:id (edit), DELETE /messages/:id (delete), GET /user/:userId/unread-count
- [ ] T033 [P] [US3] Create test/unit/test_message_model.dart with serialization and status enum handling tests
- [ ] T034 [US3] Create test/unit/test_encryption_service.dart with tests: encryptMessage and decryptMessage roundtrip, different media types handled
- [ ] T035 [US3] Create test/integration/test_message_service.dart with tests: createMessage stores with status='sent', status transitions (sent→delivered→read), editMessage updates encrypted_content and edited_at, deleteMessage removes record, paginated queries return correct order, unread count queries work
- [ ] T036 [P] [US3] Create test/integration/test_message_endpoints.dart with endpoint tests: create message, list paginated messages, update status, edit message (only by sender), delete message, verify referential integrity (message deleted if chat deleted via CASCADE)

**Checkpoint**: User Story 3 complete - users can send, receive, edit, and track message status independently

---

## Phase 6: User Story 4 - User Invitations (Priority: P2)

**Goal**: Enable users to send friend invitations with status tracking (pending/accepted/declined). Prevent duplicate pending invitations and track response timestamps.

**Independent Test**: (1) Send invitation from alice to bob, verify Invite record with status='pending', (2) Query bob's pending invitations returns the invite, (3) Bob accepts invitation, status changes to 'accepted' and responded_at set, (4) Alice can send new invitation only if previous declined, (5) Query alice's sent invitations returns all with correct statuses

### Implementation for User Story 4

- [ ] T037 [P] Create backend/lib/src/models/invite_model.dart with Invite class: id, senderId, receiverId, status (InviteStatus enum), createdAt, respondedAt; include toJson/fromJson, isPending/isAccepted/isDeclined computed properties
- [ ] T038 Create backend/lib/src/services/invite_service.dart with methods: createInvite(senderId, receiverId), getInviteById(id), getPendingInvitationsForUser(userId), getInvitationsSentByUser(userId), acceptInvite(inviteId, respondedAt=NOW()), declineInvite(inviteId, respondedAt=NOW()), checkExistingPendingInvite(senderId, receiverId), deleteInvite(id)
- [ ] T039 [US4] Create backend/lib/src/endpoints/invite_endpoints.dart with endpoints: POST /invites (create), GET /invites/pending (get pending for current user), GET /invites/sent (get sent by current user), PUT /invites/:id/accept (accept), PUT /invites/:id/decline (decline), DELETE /invites/:id (delete)
- [ ] T040 [P] [US4] Create test/unit/test_invite_model.dart with serialization and status enum handling tests
- [ ] T041 [US4] Create test/integration/test_invite_service.dart with tests: createInvite prevents duplicate pending, getPendingInvitationsForUser returns only receiver's pending invites, acceptInvite sets status='accepted' and responded_at, declineInvite allows re-sending, checkExistingPendingInvite accurately detects duplicates
- [ ] T042 [P] [US4] Create test/integration/test_invite_endpoints.dart with endpoint tests: create invite from user A to B, user B sees pending invite, B accepts, status updates, A can query sent invites, verify receiver_not_sender constraint prevents self-invite

**Checkpoint**: User Story 4 complete - users can send invitations and manage friendship requests independently

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Finalize schema, error handling, and integration testing

- [ ] T043 [P] Add migration rollback scripts (if not auto-handled by Serverpod) in backend/migrations/ with idempotent down strategies
- [ ] T044 [P] Implement comprehensive error handling in all services: unique constraint violations, foreign key violations, NOT NULL violations; map to HTTP error codes in endpoints
- [ ] T045 [P] Add database query logging and timing in backend/lib/src/services/ with performance metrics collection
- [ ] T046 [P] Create backend/test/integration/test_schema_integrity.dart: verify all tables exist, verify indexes exist on critical columns, verify foreign key constraints active, verify ENUM types created
- [ ] T047 Create backend/test/integration/test_cascade_delete_behavior.dart: verify User deletion cascades to ChatMember and Invite (CASCADE), Message cascade if chat deleted (CASCADE), but Message RESTRICT on User to preserve history; Chat deletion cascades to ChatMember and Message
- [ ] T048 Create test/integration/test_user_stories_end_to_end.dart: complete workflow test: (1) register alice and bob, (2) create chat, (3) add both users, (4) alice sends message, (5) bob accepts message, (6) verify message visible to both with correct status
- [ ] T049 [P] Create backend/README.md with: migration execution instructions, model usage examples, query patterns with index usage, troubleshooting guide (schema validation, connection pooling)
- [ ] T050 [P] Update backend/pubspec.yaml with exact versions and add dev_dependencies: test (^1.24.0), lints (^3.0.0)
- [ ] T051 Add backend/.env.example with template: DATABASE_URL, SERVERPOD_PORT, SERVERPOD_ENV
- [ ] T052 [P] Verify `docker-compose up` starts cleanly, all migrations run, health check passes at /health endpoint
- [ ] T053 [P] Create migration verification script in backend/scripts/verify_migrations.dart to validate schema against contracts/

**Checkpoint**: All implementation complete, schema verified, end-to-end tests passing, docker-compose fully operational

---

## Quality Gates

### Per-Story Gates (Complete Before Story Delivery)

- **Unit Tests**: All model serialization and business logic tests pass
- **Integration Tests**: All database operations and constraints validated
- **Endpoint Tests**: All REST/RPC endpoints return correct status codes and responses
- **Independent Verification**: Story can be demonstrated to stakeholders in isolation

### Phase 2 Foundation Gate (Must Pass Before Any Story)

✅ All 5 migrations execute successfully  
✅ All 5 tables created with correct schema  
✅ ENUM types created (message_status, invite_status)  
✅ Unique constraints on User.email, User.username  
✅ Foreign key relationships established  
✅ Indexes created on all critical columns  

### Final Integration Gate (Before PR Merge)

✅ All 52 tasks completed and verified  
✅ Schema integrity tests passing  
✅ Cascade delete behavior correct  
✅ End-to-end user story workflow passes  
✅ `docker-compose up` starts without errors  
✅ docker-compose logs show: "Serverpod ready", "Health check endpoint available"  
✅ All tests (unit, integration, endpoint) passing  
✅ Code follows Dart naming conventions  
✅ No console logging of sensitive data (passwords, keys)  

---

## Task Summary

| Phase | Count | Type |
|-------|-------|------|
| Setup | 7 | Infrastructure |
| Foundation | 5 | Database |
| US1 (User Registration) | 7 | Feature |
| US2 (Chat Creation) | 8 | Feature |
| US3 (Messaging) | 8 | Feature |
| US4 (Invitations) | 6 | Feature |
| Polish | 11 | QA & Documentation |
| **Total** | **52** | **All** |

**Estimated Implementation Time**: 40-50 developer-hours for experienced Dart/Serverpod developer

**MVP Scope**: Phase 1 + Phase 2 + Phase 3 (User Registration) + Phase 5 (Messaging) = 19 tasks = ~20 developer-hours

**All Features**: All phases = 52 tasks = ~45 developer-hours

---

## Dependency Graph

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundation) [BLOCKING]
    ↓
Phase 3 (US1 - Users) ─┐
Phase 4 (US2 - Chats) ─┼─→ Phase 7 (Polish)
Phase 5 (US3 - Messages) ┤
Phase 6 (US4 - Invites) ─┘
```

Tasks within each phase can run in parallel (marked with [P])  
Phases must complete sequentially
