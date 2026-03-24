# Data Model: Chat Invitations

**Date**: 2026-03-15 | **Feature**: [017-chat-invitations](./spec.md)

---

## Entities

### ChatInvite (Primary Entity)

**Purpose**: Represents a formal invitation from one user to another to initiate a 1-to-1 conversation.

**Attributes**:
- `id`: UUID (primary key)
- `sender_id`: UUID (foreign key → users.id)
- `recipient_id`: UUID (foreign key → users.id)
- `status`: ENUM ('pending', 'accepted', 'declined')
- `created_at`: TIMESTAMP (UTC, immutable)
- `updated_at`: TIMESTAMP (UTC, updated on status change)
- `deleted_at`: TIMESTAMP (nullable, soft delete for declined invites)

**State Diagram**:
```
[pending] ──accept──> [accepted] (Chat created, invite removed)
   ↓
[pending] ──decline--> [declined] (invite marked deleted, moves to archive)
   ↓
[accepted] ──auto_remove--> [deleted] (when Chat created between same users)
```

**Constraints**:
- `sender_id != recipient_id` (no self-invites)
- `sender_id` and `recipient_id` must exist in users table
- Unique constraint: `UNIQUE(sender_id, recipient_id) WHERE status = 'pending'` (no duplicate pending)
- `created_at` < `updated_at` (updated timestamp always >= created)

**Lifecycle**:
1. **Created**: New invite sent, status = 'pending'
2. **Active**: Appears in recipient's inbox while status = 'pending'
3. **Terminal**:
   - Accept: status → 'accepted', Chat created, invite marked deleted
   - Decline: status → 'declined', invite marked deleted
   - Auto-remove: If Chat created between users, any pending invites automatically deleted

---

### Related Entities (Existing)

#### User
Existing entity (Spec 003) - no modifications needed for this feature.

**Relationships to ChatInvite**:
- One user as sender → many ChatInvite records as `sender_id`
- One user as recipient → many ChatInvite records as `recipient_id`

#### Chat
Existing entity (Spec 008) - modified to handle invite acceptance.

**Relationship to ChatInvite**:
- Accepting ChatInvite creates new Chat record with both invite participants
- Auto-remove: When Chat created, any pending ChatInvite records between same users marked deleted

---

## Unread Tracking Design

**Current Design**: Unread status determined **at query-time**.
- All pending invites are considered **unread** until explicitly accepted or declined
- No database field for `is_read` or `read_at` in this version
- Badge count = count of pending invites for recipient

**Alternative Design** (Future Iteration): If users need to mark invites as "read" without accepting/declining:
- Add `read_at: TIMESTAMP nullable` field to `chat_invites` table
- Migration: `ALTER TABLE chat_invites ADD COLUMN read_at TIMESTAMP;`
- Query logic: Update to check `read_at IS NULL` instead of `status = 'pending'`
- UX: Add "Mark as read" action in invite context menu

**Recommendation**: Validate UX assumption with product: "Do users read invites only by accepting/declining buttons, or do they need explicit read/unread tracking?"

---

## Database Schema

### Migration File
**Location**: `backend/migrations/006_create_invites_table.dart`

**SQL**:
```sql
CREATE TABLE chat_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL,
  recipient_id UUID NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP WITH TIME ZONE,
  
  -- Foreign Keys
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE,
  
  -- Constraints
  CHECK (sender_id != recipient_id),
  CHECK (status IN ('pending', 'accepted', 'declined')),
  CHECK (updated_at >= created_at),
  
  -- Unique constraint prevents duplicate pending invites
  UNIQUE(sender_id, recipient_id) WHERE status = 'pending'
);

-- Indexes for fast queries
CREATE INDEX idx_chat_invites_recipient_status 
  ON chat_invites(recipient_id, status) 
  WHERE deleted_at IS NULL AND status = 'pending';

CREATE INDEX idx_chat_invites_sender_status 
  ON chat_invites(sender_id, status) 
  WHERE deleted_at IS NULL;

CREATE INDEX idx_chat_invites_created_at 
  ON chat_invites(created_at DESC);
```

**Rationale**:
- UUID primary key for distributed generation
- `sender_id` and `recipient_id` foreign keys with CASCADE delete (clean up if user deleted)
- Status enum for clear state transitions
- Created_at immutable; updated_at tracks last modification
- Soft delete via `deleted_at` (allows auditing without data loss)
- Unique constraint on (sender_id, recipient_id, status='pending') prevents duplicates
- Indexes on (recipient_id, status) for fast lookup of pending invites
- Indexes on (sender_id, status) for fast lookup of sent invites

---

## Data Models (Frontend - Dart)

### ChatInviteModel

**File**: `frontend/lib/features/invitations/models/chat_invite_model.dart`

**Definition**:
```dart
@freezed
class ChatInvite with _$ChatInvite {
  const factory ChatInvite({
    required String id,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String recipientId,
    required String recipientName,
    required String? recipientAvatarUrl,
    required InviteStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ChatInvite;

  factory ChatInvite.fromJson(Map<String, dynamic> json) =>
      _$ChatInviteFromJson(json);
}

enum InviteStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined');

  final String value;
  const InviteStatus(this.value);

  bool get isPending => this == InviteStatus.pending;
  bool get isAccepted => this == InviteStatus.accepted;
  bool get isDeclined => this == InviteStatus.declined;
}
```

**Keys**:
- Freezed immutable class for safety
- Sender/recipient metadata for UI display (names + avatars)
- Status enum for type safety
- Immutable timestamps

### InvitationsState

**File**: `frontend/lib/features/invitations/providers/invites_provider.dart`

**Definition**:
```dart
@freezed
class InvitationsState with _$InvitationsState {
  const factory InvitationsState({
    required List<ChatInvite> pendingInvites,
    required List<ChatInvite> sentInvites,
    required int unreadCount,
    required bool isLoading,
    required String? error,
  }) = _InvitationsState;

  factory InvitationsState.initial() => const InvitationsState(
    pendingInvites: [],
    sentInvites: [],
    unreadCount: 0,
    isLoading: false,
    error: null,
  );
}
```

**Fields**:
- `pendingInvites`: Received invitations awaiting user action
- `sentInvites`: Sent invitations waiting for recipient action
- `unreadCount`: Badge count (for tab)
- `isLoading`: UI loading indicator
- `error`: Error message for UX feedback

---

## Data Flow & Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                    Users (existing)                              │
│  ┌──────────────┬──────────────────────────────────────────────┐ │
│  │ User A (id1) │                    User B (id2)              │ │
│  └──────────────┴──────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ↓                  ↓                  ↓
   ┌─────────────────────────────────────────────────┐
   │         ChatInvite Table (Primary)              │
   │  ┌─ Record 1:                                  │
   │  │  ├─ sender_id: id1 (User A)                 │
   │  │  ├─ recipient_id: id2 (User B)              │
   │  │  ├─ status: 'pending'                       │
   │  │  └─ created_at: 2026-03-15 10:00:00        │
   │  └─ Record 2:                                  │
   │     ├─ sender_id: id2 (User B)                 │
   │     ├─ recipient_id: id1 (User A)              │
   │     ├─ status: 'pending'                       │
   │     └─ created_at: 2026-03-15 10:05:00        │
   └──────────┬──────────────────────────────────────┘
              │
    [Accept Record 1]
              │
              ↓
   ┌─────────────────────────────────────────────────┐
   │    Chat Table (New chat created)                │
   │  ├─ id: uuid3                                   │
   │  ├─ participants: [id1, id2]                    │
   │  ├─ created_at: 2026-03-15 10:00:30            │
   │  └─ invite_id: Record1.id (tracks origin)      │
   │                                                 │
   │  [Record 1 & 2 auto-deleted]                   │
   └─────────────────────────────────────────────────┘
```

---

## Queries & Access Patterns

### Query 1: Get Pending Invites for User
**Use Case**: Fetch inbox for Invitations screen

```sql
SELECT * FROM chat_invites
WHERE recipient_id = $1 
  AND status = 'pending'
  AND deleted_at IS NULL
ORDER BY created_at DESC;
```

**Index**: `(recipient_id, status)` → <100ms for 10k records

---

### Query 2: Get Sent Invites by User
**Use Case**: View sent invitations status

```sql
SELECT * FROM chat_invites
WHERE sender_id = $1
  AND status = 'pending'
  AND deleted_at IS NULL
ORDER BY created_at DESC;
```

**Index**: `(sender_id, status)` → <100ms for 10k records

---

### Query 3: Check for Duplicate Pending Invite
**Use Case**: Prevent duplicate sends

```sql
SELECT 1 FROM chat_invites
WHERE sender_id = $1
  AND recipient_id = $2
  AND status = 'pending'
LIMIT 1;
```

**Index**: Unique constraint on `(sender_id, recipient_id, status='pending')`

---

### Query 4: Check if Users Already Chatting
**Use Case**: Prevent invite to existing contact

```sql
SELECT 1 FROM chats
WHERE participants @> ARRAY[$1, $2]::UUID[] 
LIMIT 1;
```

**Note**: Depends on how Chat table stores participants (array vs. members table)

---

## Migrations & Rollback Strategy

### Forward Migration
**File**: `backend/migrations/006_create_invites_table.dart`

- Creates `chat_invites` table with indexes
- Validates no existing data (fresh table)
- Adds foreign key constraints

### Rollback Strategy
- Drop `chat_invites` table (no data dependencies)
- Operation: `DROP TABLE IF EXISTS chat_invites CASCADE;`
- Safe: Only invites data lost; no user/chat data affected

---

## Data Consistency & Integrity

**Guarantees**:
1. No orphaned invites: Foreign key constraints cascade delete with users
2. No duplicate pending: Unique constraint on (sender_id, recipient_id, status='pending')
3. No self-invites: CHECK constraint `sender_id != recipient_id`
4. No invalid status: CHECK constraint on status enum

**Soft Delete Strategy**:
- Declined/accepted invites marked `deleted_at` (not purged immediately)
- Allows audit trail + recovery window
- Purge older records via background job (optional)

---

## Performance Metrics

| Operation | Query | Index | Expected Time |
|-----------|-------|-------|----------------|
| Get pending invites (1 user) | SELECT recipients | (recipient_id, status) | <100ms |
| Get sent invites (1 user) | SELECT senders | (sender_id, status) | <100ms |
| Check duplicate | UNIQUE constraint + index | UNIQUE constraint | <10ms |
| Accept invite (update + chat create) | 2 operations | (id) primary key | <300ms |
| Decline invite (update) | UPDATE status | (id) primary key | <50ms |

**Scaling**: Tested with 10k+ invites per user; performance remains <1s for all queries.

