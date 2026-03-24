# Phase 1 Design: Data Model & Entity Relationships

**Date**: March 15, 2026  
**Feature**: Invitation Send, Accept, Reject, and Cancel  
**Status**: ✅ Design Complete

---

## Entity Definitions

### Invitation (Core Entity)

**Purpose**: Represents a request from one user to another to initiate a conversation.

**Attributes**:
```dart
class ChatInviteModel {
  final String id;                      // UUID, primary key
  final String senderId;                // Foreign key → User.id
  final String senderName;              // Denormalized for display
  final String? senderAvatarUrl;        // Denormalized for display
  final String receiverId;              // Foreign key → User.id
  final String recipientName;           // Denormalized for display
  final String? recipientAvatarUrl;     // Denormalized for display
  final InvitationStatus status;        // Enum: pending, accepted, rejected, canceled
  final DateTime createdAt;             // Server timestamp (invitation sent)
  final DateTime? respondedAt;          // Server timestamp (if accepted/rejected)
  final DateTime? canceledAt;           // Server timestamp (if canceled)
}

enum InvitationStatus {
  pending,    // Invitation sent, awaiting recipient action
  accepted,   // Recipient accepted; chat was created
  rejected,   // Recipient rejected; no chat created
  canceled    // Sender canceled before recipient responded
}
```

**Validation Rules**:
- `id`: Must be non-empty UUID
- `senderId` ≠ `receiverId` (FR-011: prevent self-invitations)
- `status`: Must be one of {pending, accepted, rejected, canceled}
- `createdAt`: Must be server time (never client-provided)
- `respondedAt`: NULL if status = "pending"; non-NULL if status = "accepted" or "rejected"
- `canceledAt`: NULL if status ≠ "canceled"; non-NULL if status = "canceled"

**Database Mapping**:
```sql
CREATE TABLE invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'accepted', 'rejected', 'canceled')),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP,
  canceled_at TIMESTAMP,
  CONSTRAINT no_self_invites CHECK (sender_id != receiver_id),
  CONSTRAINT responded_at_only_when_responded 
    CHECK ((status IN ('accepted', 'rejected') AND responded_at IS NOT NULL)
        OR (status = 'pending' AND responded_at IS NULL)
        OR (status = 'canceled' AND responded_at IS NULL))
);

-- Indexes for common queries
CREATE INDEX idx_invites_receiver_status 
  ON invites(receiver_id, status) 
  WHERE status = 'pending';  -- Fast lookup for recipient's pending invites

CREATE INDEX idx_invites_sender_status 
  ON invites(sender_id, status);  -- Fast lookup for sender's sent invites
```

---

### Chat (Related Entity)

**Purpose**: Represents an active conversation between two or more users. Updated when invitation accepted.

**Relevant Attributes** (subset shown):
```dart
class ChatModel {
  final String id;
  final List<String> participantIds;
  final DateTime createdAt;
  final String? initiatedByInvitationId;  // Links back to invitation
  // ... other fields
}
```

**Relationship**:
- When Invitation transitions to "accepted" status:
  - System MUST create Chat (or add participant if chat exists)
  - Chat.initiatedByInvitationId MUST be set to Invitation.id
  - FC-006: "System MUST create a new chat when an invitation is accepted"

---

### User (Existing Entity)

**Purpose**: Represents a person in the system. Already implemented.

**Relevant Attributes**:
```dart
class UserModel {
  final String id;
  final String username;
  final String? profilePictureUrl;
  final List<String> blockedUserIds;  // For blocking validation
  // ... other fields
}
```

**Invitation System Interactions**:
- User.id referenced as sender_id or receiver_id in Invitation
- User.blockedUserIds checked before accepting invitation (FR-N9: respect blocking)
- User.username + profilePictureUrl denormalized into invitation DTO for frontend display

---

## State Machine: Invitation Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    INVITATION LIFECYCLE                          │
└─────────────────────────────────────────────────────────────────┘

                         [Create]
                             │
                             ▼
                      ┌──────────────┐
                      │   PENDING    │  ◄─── Initial state after send
                      │ (receiver    │
                      │  awaiting)   │
                      └──┬───────┬───┘
                         │       │
                   [Accept]  [Reject]  [Cancel] (by sender)
                         │       │          │
                         ▼       ▼          ▼
                    ┌─────────┬─────────┬─────────┐
                    │         │         │         │
                 ACCEPTED  REJECTED  CANCELED  N/A
                    │         │         │
                    └─────────┴─────────┘
                         │
                    (Final States)
                    No transitions out
```

**State Transition Rules**:

| From | To | Trigger | Conditions | Effect |
|------|-----|---------|-----------|--------|
| PENDING | ACCEPTED | Recipient accepts (FR-005) | receiver_id = current_user | Chat created (FR-006) |
| PENDING | REJECTED | Recipient rejects (FR-007) | receiver_id = current_user | Invitation marked rejected |
| PENDING | CANCELED | Sender cancels (FR-004) | sender_id = current_user | Invitation marked canceled |
| ACCEPTED | - | N/A | Final state | No transitions possible |
| REJECTED | N/A | (Wait 30 days) | Auto-deletion policy | Q3: Record purged after 30 days |
| CANCELED | N/A | N/A | Final state | No transitions possible |

**Race Condition Handling (Q2: Timestamp-Based)**:
- If Accept and Cancel operations occur concurrently:
  - Database executes whichever transaction commits first
  - Database timestamp (created_at order) acts as tiebreaker
  - Loser transaction receives database constraint error or conflict resolution
  - Example: If Accept transaction commits at 13:47:01.001 and Cancel at 13:47:01.002, Accept wins

---

## Frontend State Management (Riverpod)

### Provider Hierarchy

```dart
// Core providers (read fresh data from API)
final inviteApiServiceProvider = Provider(
  (ref) => InviteApiService(ref.watch(httpClientProvider)),
);

// Async data providers (fetch from backend)
final pendingInvitesProvider = FutureProvider<List<ChatInviteModel>>((ref) async {
  final service = ref.watch(inviteApiServiceProvider);
  return service.getPendingInvites();
});

final sentInvitesProvider = FutureProvider<List<ChatInviteModel>>((ref) async {
  final service = ref.watch(inviteApiServiceProvider);
  return service.getSentInvites();
});

// Computed state (combine pending + sent)
final allInvitesProvider = Provider<AsyncValue<List<ChatInviteModel>>>((ref) async {
  final pending = ref.watch(pendingInvitesProvider);
  final sent = ref.watch(sentInvitesProvider);
  return [
    ...await pending.when(
      data: (data) => data,
      error: (_, __) => [],
      loading: () => [],
    ),
    ...await sent.when(
      data: (data) => data,
      error: (_, __) => [],
      loading: () => [],
    ),
  ];
});

// Actions (call backend, then invalidate cache)
final acceptInvitationNotifier = StateNotifierProvider<AcceptInvitationNotifier, AsyncValue<void>>(
  (ref) => AcceptInvitationNotifier(ref),
);

class AcceptInvitationNotifier extends StateNotifier<AsyncValue<void>> {
  AcceptInvitationNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> accept(String invitationId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(inviteApiServiceProvider);
      await service.acceptInvitation(invitationId);
      // Invalidate cache to force refresh
      ref.invalidate(pendingInvitesProvider);
      ref.invalidate(sentInvitesProvider);
    });
  }
}
```

### Cache Invalidation Strategy

**Scenario 1**: User accepts invitation
1. Frontend calls backend: `POST /api/invites/{id}/accept`
2. Backend: Transitions status to "accepted"; creates Chat
3. Frontend: Invalidates pendingInvitesProvider
4. Frontend: Refetches pending invites (now empty for that invite)
5. UI updates automatically (invite disappears from pending list)

**Scenario 2**: Sender cancels while receiver viewing
1. User A cancels invitation via sent list
2. Frontend calls backend: `DELETE /api/invites/{id}`
3. Backend: Updates status to "canceled"
4. User B still viewing pending list (invitation cached)
5. On next refresh or after 3-5 second poll: Frontend refetches
6. Invitation no longer in backend response
7. UI updates (invitation removed from pending list)

---

## API Contract

### Request/Response DTOs

**Invitation DTO** (returned by all endpoints):
```json
{
  "id": "7540c74f-5bd3-469d-9a46-82090d624aa7",
  "senderId": "bfd3a96a-ab36-442c-9b4e-276050b87678",
  "senderName": "alice",
  "senderAvatarUrl": null,
  "recipientId": "b8465fd4-56e0-4f97-9a4f-9e2cb862d444",
  "recipientName": "bob",
  "recipientAvatarUrl": null,
  "status": "pending",
  "createdAt": "2026-03-15T13:47:18.522694Z",
  "respondedAt": null
}
```

**Error Response**:
```json
{
  "error": "duplicate_invitation",
  "message": "You have already sent a pending invitation to this user",
  "details": {
    "existingInvitationId": "7540c74f-5bd3-469d-9a46-82090d624aa7"
  }
}
```

See [contracts/](./contracts/) for full API specifications.

---

## Data Consistency Guarantees

### Invariants (Properties that must always hold)

1. **No Duplicate Pending Invitations** (FR-010)
   - At most one invitation with (sender_id, receiver_id, status='pending')
   - Database constraint + Application check before creation

2. **Valid Owner Operations**
   - Accept/Reject: Only receiver_id = current_user can call
   - Cancel: Only sender_id = current_user can call

3. **Status Finality**
   - Once status ∈ {accepted, rejected, canceled}, no further transitions

4. **Timestamp Ordering**
   - respondedAt ≥ createdAt (always)
   - canceledAt on same order as created_at (same millisecond possible)

### Referential Integrity

- sender_id → users.id (ON DELETE CASCADE)
- receiver_id → users.id (ON DELETE CASCADE)
- If user deleted, their invitations automatically purged

---

## Performance Characteristics

**Queries used throughout system**:

| Query | Index | Avg Time | Notes |
|-------|-------|----------|-------|
| Get pending invites for user | idx_invites_receiver_status | O(1) | Most common; bottleneck on high load |
| Get sent invites for user | idx_invites_sender_status | O(1) | Common; updates on status change |
| Create invitation | N/A | O(1) | Two INSERT checks; Foreign key validations |
| Accept/Reject/Cancel | N/A | O(1) | Single UPDATE statement |
| Check duplicate | idx_invites_sender_receiver_pending | O(1) | Before CREATE; prevents duplicates |

---

## Summary

- **Entities**: Invitation (core), Chat (related), User (existing)
- **State Machine**: Pending → {Accepted, Rejected, Canceled} (final)
- **Race Condition Resolution**: Timestamp-based (Q2)
- **Data Retention**: Rejected invitations auto-delete after 30 days (Q3)
- **Frontend State**: Riverpod providers with cache invalidation strategy
- **Database**: PostgreSQL with constraints + indexes for performance
