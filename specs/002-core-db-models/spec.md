# Feature Specification: Core Database Models

**Feature Branch**: `002-core-db-models`  
**Created**: 2026-03-10  
**Status**: Draft  
**Input**: Define backend data models and database schema for User, Chat, ChatMember, Message, and Invite entities

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - User Registration & Profile Setup (Priority: P1)

When a new user joins the messenger app, they need to create an account with email and password. The system must store their profile information securely and ensure email uniqueness for login and recovery purposes.

**Why this priority**: User registration is the foundational flow - without user accounts, no other features work. This is the gateway to the entire platform.

**Independent Test**: Can be tested by: (1) Creating a new user account with valid email/password, (2) Verifying the user record is persisted in the database with correct fields, (3) Attempting duplicate email registration fails, (4) User can log back in with stored credentials.

**Acceptance Scenarios**:

1. **Given** no user exists with email "alice@example.com", **When** new user registers with email and password, **Then** user record is created with email_verified=false and created_at timestamp
2. **Given** user "alice@example.com" exists, **When** another user tries to register with same email, **Then** registration fails (email unique constraint)
3. **Given** user has registered, **When** profile picture URL and about_me are provided, **Then** profile fields are persisted and retrievable
4. **Given** user has not verified email, **When** email verification completes, **Then** email_verified is set to true

---

### User Story 2 - Chat Creation & Membership (Priority: P1)

Users need to create one-on-one or group chats and invite other users to join. The system must track who created the chat, when it was created, and maintain a clean member list.

**Why this priority**: Chat creation is essential functionality tied directly to the messenger's core value proposition. P1 because messaging flows depend on properly initialized chats.

**Independent Test**: Can be tested by: (1) Creating a new chat, (2) Verifying chat record with correct metadata is stored, (3) Adding multiple users as members, (4) Checking member list retrieval is correct.

**Acceptance Scenarios**:

1. **Given** user "alice" wants to chat with "bob", **When** chat is created, **Then** chat record stores created_at timestamp
2. **Given** chat exists, **When** users alice and bob are added as members, **Then** ChatMember records link both users to that chat
3. **Given** user alice archives the chat, **When** archived_by_users list is checked, **Then** alice's ID is in that list
4. **Given** archived_by_users list contains user IDs, **When** filtering chats for display, **Then** archived chats are hidden for those users

---

### User Story 3 - Message Sending & Status Tracking (Priority: P1)

Users need to send messages to chats with media support and track delivery/read status. The system must store encrypted message content and handle media attachments.

**Why this priority**: Messaging is the core feature of a messenger app. Every user interaction revolves around sending and receiving messages securely.

**Independent Test**: Can be tested by: (1) Sending a text message to a chat, (2) Verifying message record with sender, content, and timestamp is stored, (3) Sending message with media attachment, (4) Checking message status progression (sent → delivered → read).

**Acceptance Scenarios**:

1. **Given** message is sent by user alice to chat, **When** message is stored, **Then** message record contains sender_id, encrypted_content, created_at, and status='sent'
2. **Given** message with image attachment exists, **When** message is retrieved, **Then** media_url and media_type='image' are populated
3. **Given** message is delivered to recipients, **When** status is updated, **Then** status field changes to 'delivered'
4. **Given** message has been read, **When** status is checked, **Then** status reflects 'read' state
5. **Given** user edits a sent message, **When** message is updated, **Then** edited_at timestamp is recorded

---

### User Story 4 - User Invitations (Priority: P2)

Users can send friend invitations to other users. The system must track invitation sender, receiver, and status (pending/accepted/declined) to manage friend relationships.

**Why this priority**: Invitations enable social connection and community building. P2 because core messaging works without it, but social features enhance engagement.

**Independent Test**: Can be tested by: (1) Sending invitation from alice to bob, (2) Verifying invitation record with pending status is created, (3) Accepting/declining invitation updates status, (4) Retrieving pending invitations for a user shows correct records.

**Acceptance Scenarios**:

1. **Given** alice wants to invite bob, **When** invitation is created, **Then** Invite record has sender_id=alice, receiver_id=bob, status='pending'
2. **Given** invitation exists with status='pending', **When** bob accepts the invitation, **Then** status changes to 'accepted'
3. **Given** invitation exists with status='pending', **When** bob declines the invitation, **Then** status changes to 'declined'
4. **Given** alice has sent multiple invitations, **When** bob's pending invitations are queried, **Then** only invitations to bob with status='pending' are returned

### Edge Cases

- What happens when a user is deleted - should ChatMember records for that user be cascaded or soft-deleted?
- How should message status transitions work - can a message go from 'read' back to 'delivered'?
- If a user is removed from a chat, should their messages remain visible or be hidden?
- What happens if both users archive the same one-on-one chat - is it still queryable from the database?
- Can a chat exist without any members?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST create and persist User records with email, username, password_hash, email_verified flag, profile_picture_url, about_me, and created_at timestamp
- **FR-002**: System MUST enforce unique constraint on User.email to prevent duplicate accounts
- **FR-003**: System MUST enforce unique constraint on User.username to ensure unique identity display
- **FR-004**: System MUST create and persist Chat records with created_at timestamp and archived_by_users list (UUID array for user IDs who have archived)
- **FR-005**: System MUST create and persist ChatMember records linking users to chats with user_id and chat_id foreign keys, composite primary key (user_id, chat_id)
- **FR-006**: System MUST create and persist Message records with chat_id, sender_id, encrypted_content, media_url, media_type, status, created_at, and edited_at
- **FR-007**: System MUST support message status values: 'sent', 'delivered', 'read' with state transitions enforced at application layer
- **FR-008**: System MUST store media_type values such as 'image', 'video', 'audio', 'file' for attachment classification
- **FR-009**: System MUST create and persist Invite records with sender_id, receiver_id, and status (pending/accepted/declined) with CHECK constraint preventing sender_id == receiver_id
- **FR-010**: System MUST enforce referential integrity with CASCADE delete for ChatMember (User/Chat deletion), CASCADE delete for Invite (User deletion), and RESTRICT delete for Message sender_id to preserve chat history
- **FR-011**: System MUST store encrypted message content using AES-256-GCM encryption applied at application layer before persistence

- **User**: Represents a system user with authentication credentials and profile information. Key attributes: id, email (unique), username (unique), password_hash (bcrypt or similar), email_verified (boolean), profile_picture_url, about_me (text), created_at (timestamp). Relationships: one-to-many with ChatMember, one-to-many with Message (as sender), one-to-many with Invite (as sender and receiver).

- **Chat**: Represents a conversation thread (one-on-one or group). Key attributes: id, created_at (timestamp), archived_by_users (array/JSON of user IDs who have archived). Relationships: one-to-many with ChatMember, one-to-many with Message.

- **ChatMember**: Junction table linking users to chats for membership management. Key attributes: user_id (foreign key), chat_id (foreign key), composite primary key on (user_id, chat_id). Relationships: many-to-one with User and Chat.

- **Message**: Represents a single message in a chat with optional media. Key attributes: id, chat_id (foreign key), sender_id (foreign key), encrypted_content (text), media_url (nullable), media_type (nullable), status (enum), created_at (timestamp), edited_at (nullable timestamp). Relationships: many-to-one with Chat and User (sender).

- **Invite**: Represents a friend/connection invitation. Key attributes: id, sender_id (foreign key), receiver_id (foreign key), status (enum: pending/accepted/declined), created_at (timestamp), responded_at (nullable timestamp). Relationships: many-to-one with User (sender and receiver).

## Success Criteria

- **SC-001**: All database migrations execute successfully without errors and complete in under 30 seconds
- **SC-002**: All six tables (User, Chat, ChatMember, Message, Invite) are created with correct schema and constraints verified
- **SC-003**: Unique constraints on User.email and User.username prevent duplicate inserts (enforced by database)
- **SC-004**: Foreign key relationships enforce referential integrity - deleting a user cascades appropriately (ChatMember/Invite deleted, Messages preserved via RESTRICT)
- **SC-005**: Database indexes on user_id, chat_id, email, and status fields reduce query time to under 100ms for typical queries
- **SC-006**: Test suite verifies 6 migrations complete sequentially and idempotently (can be re-run safely)
- **SC-007**: Data retrieval tests confirm all entity relationships work correctly - can fetch user's chats, chat members, messages in a chat, and pending invitations
- **SC-008**: 100% of Acceptance Scenarios pass when tested against the running database schema

## Assumptions

- Database engine is PostgreSQL (common choice for production; SQL syntax may vary for other databases)
- UUID will be used for primary keys (id fields) for distributed system compatibility
- password_hash assumes bcrypt or similar industry-standard algorithm (actual hashing done at application layer)
- archived_by_users is stored as PostgreSQL UUID[] array type to maintain type consistency with User.id
- Message status is an ENUM type with values: 'sent', 'delivered', 'read'
- Invite status is an ENUM type with values: 'pending', 'accepted', 'declined'
- Timestamps use UTC and database native timestamp types (TIMESTAMP WITH TIME ZONE)
- Soft deletes are not required initially; CASCADE delete handles related ephemeral records (ChatMember, Invite); RESTRICT on Message preserves history
- No audit logging or historical tracking required for v1 schema
- Message encryption applied at application layer (cryptography package AES-256-GCM); media_url/media_type stored plaintext for v1

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]
