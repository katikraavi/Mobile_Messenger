# Phase 1 Design: Data Model

**Date**: 2026-03-10  
**Feature**: 002-core-db-models  
**Status**: Design Complete

## Data Model Overview

Core messenger data model supporting 5 entities with relationships, constraints, and indexes designed for security, performance, and integrity.

## Entity Definitions

### Entity 1: User

**Purpose**: Represents a system user with authentication credentials and profile information

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique user identifier
- `email` (VARCHAR(255), UNIQUE, NOT NULL): User's email for login and recovery
- `username` (VARCHAR(50), UNIQUE, NOT NULL): User's display name (for mentions, search)
- `password_hash` (VARCHAR(255), NOT NULL): bcrypt hash of password (never plaintext)
- `email_verified` (BOOLEAN, DEFAULT false): Flag indicating email verification status
- `profile_picture_url` (TEXT, nullable): URL to user's avatar (stored in object storage, path only in DB)
- `about_me` (TEXT, nullable): User's bio or status message
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Account creation timestamp (UTC)

**Relationships**:
- One-to-Many with ChatMember: User can be member of multiple chats (cascade delete)
- One-to-Many with Message: User can send multiple messages (restrict delete, preserves history)
- One-to-Many with Invite (sender): User can send multiple invitations (cascade delete)
- One-to-Many with Invite (receiver): User can receive multiple invitations (cascade delete)

**Constraints**:
- UNIQUE(email): Prevent duplicate account registration
- UNIQUE(username): Ensure unique display identity
- NOT NULL: email, username, password_hash, email_verified, created_at
- CHECK(email like '%@%.%'): Email format validation

**Indexes**:
- PRIMARY KEY on id
- UNIQUE INDEX on email (login queries)
- UNIQUE INDEX on username (mention/search queries)
- INDEX on created_at (user_id list pagination)

---

### Entity 2: Chat

**Purpose**: Represents a conversation thread (one-on-one or group)

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique chat identifier
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Chat creation timestamp (UTC)
- `archived_by_users` (UUID[], DEFAULT '{}'::UUID[]): Array of user IDs who have archived (UUID array for consistency with User.id)

**Relationships**:
- One-to-Many with ChatMember: Chat contains multiple member relationships
- One-to-Many with Message: Chat contains multiple messages

**Constraints**:
- NOT NULL: created_at
- DEFAULT empty array: archived_by_users starts empty

**Indexes**:
- PRIMARY KEY on id
- INDEX on created_at (for sorting chats by recency)

**Design Notes**:
- No explicit creator field; creator is first ChatMember entry
- No chat name field in schema (name stored in first message or application cache)
- archived_by_users: When user archives, their ID added to array; when user retrieves chats, filtered by `NOT (user_id = ANY(archived_by_users))`

---

### Entity 3: ChatMember

**Purpose**: Junction table linking users to chats (manages membership)

**Fields**:
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL)
- `chat_id` (UUID, FOREIGN KEY → Chat.id, NOT NULL)
- `joined_at` (TIMESTAMP WITH TIME ZONE, DEFAULT NOW()): When user joined chat
- `left_at` (TIMESTAMP WITH TIME ZONE, nullable): When user left chat (if applicable)

**Relationships**:
- Many-to-One with User: Multiple members belong to one user
- Many-to-One with Chat: Multiple members belong to one chat

**Constraints**:
- PRIMARY KEY (user_id, chat_id): Composite key ensures one membership per user per chat
- FOREIGN KEY user_id → User.id ON DELETE CASCADE: Remove membership if user deleted
- FOREIGN KEY chat_id → Chat.id ON DELETE CASCADE: Remove membership if chat deleted
- NOT NULL: user_id, chat_id, joined_at
- CHECK (left_at IS NULL OR left_at > joined_at)

**Indexes**:
- PRIMARY KEY on (user_id, chat_id)
- INDEX on user_id (find all chats for a user)
- INDEX on chat_id (find all users in a chat)
- INDEX on (chat_id, joined_at) (list recent members)

**Design Notes**:
- joined_at/left_at allow tracking join/leave history
- Composite PK prevents duplicate memberships
- CASCADE delete ensures clean database state

---

### Entity 4: Message

**Purpose**: Represents a single message in a chat with optional media and encryption

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique message identifier
- `chat_id` (UUID, FOREIGN KEY → Chat.id, NOT NULL): Chat containing message
- `sender_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User who sent message
- `encrypted_content` (TEXT, NOT NULL): AES-256-GCM encrypted message body (application-encrypted)
- `media_url` (TEXT, nullable): URL to media file (if attachment included, path only)
- `media_type` (VARCHAR(20), nullable): Classification of media ('image', 'video', 'audio', 'file')
- `status` (message_status ENUM, DEFAULT 'sent'): Delivery state (sent/delivered/read)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): When message was sent (UTC)
- `edited_at` (TIMESTAMP WITH TIME ZONE, nullable): When message was last edited

**Relationships**:
- Many-to-One with Chat: Multiple messages belong to one chat
- Many-to-One with User: Multiple messages sent by one user (restrict delete preserves history)

**Constraints**:
- FOREIGN KEY chat_id → Chat.id ON DELETE CASCADE: Delete messages if chat deleted
- FOREIGN KEY sender_id → User.id ON DELETE RESTRICT: Prevent user deletion if messages exist
- NOT NULL: chat_id, sender_id, encrypted_content, created_at, status
- CHECK (status IN ('sent', 'delivered', 'read'))
- CHECK (edited_at IS NULL OR edited_at >= created_at)

**Indexes**:
- PRIMARY KEY on id
- INDEX on (chat_id, created_at DESC) (message pagination - most recent first)
- INDEX on sender_id (find user's sent messages)
- INDEX on status (queries by delivery state)
- INDEX on created_at (time-range queries, message history)

**Design Notes**:
- encrypted_content is always TEXT, encryption applied in Dart `cryptography` library before persistence
- media_url is path only; full URL constructed by application
- Status transitions: sent → delivered → read (application enforces, database validates)
- edited_at preserved for audit trail, enables "edited" indicator in UI

---

### Entity 5: Invite

**Purpose**: Represents a friend/connection invitation between users

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique invitation identifier
- `sender_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User sending invitation
- `receiver_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User receiving invitation
- `status` (invite_status ENUM, DEFAULT 'pending'): Invitation state (pending/accepted/declined)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): When invitation was created (UTC)
- `responded_at` (TIMESTAMP WITH TIME ZONE, nullable): When invitation was accepted/declined

**Relationships**:
- Many-to-One with User (sender): User can send multiple invitations (cascade delete)
- Many-to-One with User (receiver): User can receive multiple invitations (cascade delete)

**Constraints**:
- FOREIGN KEY sender_id → User.id ON DELETE CASCADE: Delete invitations if sender deleted
- FOREIGN KEY receiver_id → User.id ON DELETE CASCADE: Delete invitations if receiver deleted
- NOT NULL: sender_id, receiver_id, created_at, status
- CHECK (sender_id != receiver_id): User cannot invite themselves
- CHECK (responded_at IS NULL OR responded_at >= created_at)
- UNIQUE(sender_id, receiver_id, status='pending'): Prevent duplicate pending invitations

**Indexes**:
- PRIMARY KEY on id
- INDEX on receiver_id (find pending invitations for user - notifications)
- INDEX on (status, created_at DESC) (find active/pending invitations)
- INDEX on sender_id (find invitations sent by user)

**Design Notes**:
- Status lifecycle: pending → (accepted|declined)
- responded_at tracks when action taken (for UI timestamps)
- UNIQUE constraint only for pending status (allows resending after decline)
- No "blocked" state in v1 (future enhancement)

---

## Relationships Diagram

```
User ──┬─ (1:N) ──→ ChatMember ─ (N:1) ──→ Chat
       │
       ├─ (1:N) ──→ Message (sender_id, RESTRICT DELETE to preserve history)
       │
       ├─ (1:N) ──→ Invite (sender_id, CASCADE DELETE)
       │
       └─ (1:N) ──→ Invite (receiver_id, CASCADE DELETE)

Chat ──┬─ (1:N) ──→ ChatMember (CASCADE DELETE)
       │
       └─ (1:N) ──→ Message (chat_id, CASCADE DELETE)
```

## Validation Rules

| Entity | Rule | Type |
|--------|------|------|
| User | email UNIQUE | Database constraint |
| User | username UNIQUE | Database constraint |
| User | email NOT NULL | Database constraint |
| User | password_hash NOT NULL | Database constraint |
| ChatMember | (user_id, chat_id) composite PK | Database constraint |
| Message | chat_id NOT NULL | Database constraint |
| Message | status = (sent\|delivered\|read) | ENUM constraint |
| Message | edited_at >= created_at | CHECK constraint |
| Message | sender_id != NULL | NOT NULL constraint (RESTRICT prevents user deletion) |
| Invite | sender_id != receiver_id | CHECK constraint |
| Invite | (sender_id, receiver_id, status) unique when pending | Partial unique index |
| Invite | responded_at >= created_at | CHECK constraint |
| Invite | status = (pending\|accepted\|declined) | ENUM constraint |

## Performance Projection

| Query Type | Indexes Used | Est. Time |
|-----------|--------------|-----------|
| User login by email | UNIQUE(email) | <1ms |
| User's chat list (limit 50) | INDEX(user_id) on ChatMember | 5-10ms |
| Messages in chat (pagination) | INDEX(chat_id, created_at DESC) | 10-20ms |
| Pending invitations for user | INDEX(receiver_id, status) | 5-10ms |
| User's sent messages | INDEX(sender_id, created_at) | 10-20ms |
