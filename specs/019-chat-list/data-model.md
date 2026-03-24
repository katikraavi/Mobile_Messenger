# Phase 1: Data Model

**Purpose**: Define entities, relationships, and validation rules for Chat List feature.  
**Date**: 2026-03-15  
**Status**: Complete

---

## Entity Definitions

### 1. Chat Entity

**Purpose**: Represents a 1:1 conversation between two users.

**Dart Model** (`chat_model.dart`):
```dart
import 'package:json_annotation/json_annotation.dart';

part 'chat_model.g.dart';

@JsonSerializable()
class Chat {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isParticipant1Archived;
  final bool isParticipant2Archived;
  
  /// Last message in this chat (for list display)
  /// Nullable: chat may have no messages yet
  final Message? lastMessage;

  Chat({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    required this.createdAt,
    required this.updatedAt,
    required this.isParticipant1Archived,
    required this.isParticipant2Archived,
    this.lastMessage,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
  Map<String, dynamic> toJson() => _$ChatToJson(this);

  /// Helper: Get other participant ID for current user
  String getOtherId(String currentUserId) {
    if (currentUserId == participant1Id) return participant2Id;
    if (currentUserId == participant2Id) return participant1Id;
    throw ArgumentError('Current user not in this chat');
  }

  /// Helper: Check if current user has archived this chat
  bool isArchivedForUser(String userId) {
    if (userId == participant1Id) return isParticipant1Archived;
    if (userId == participant2Id) return isParticipant2Archived;
    return false;
  }
}
```

**PostgreSQL Schema**:
```sql
CREATE TABLE chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participant_2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_participant_1_archived BOOLEAN NOT NULL DEFAULT FALSE,
  is_participant_2_archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Constraint: enforce 1:1 relationships (no duplicates)
  UNIQUE(participant_1_id, participant_2_id),
  
  -- Constraint: prevent self-chat
  CHECK(participant_1_id <> participant_2_id)
);

-- Index for efficient list query (find all active chats for user)
CREATE INDEX idx_chats_participant_1_active 
ON chats(participant_1_id, updated_at DESC) 
WHERE is_participant_1_archived = FALSE;

-- Separate index for participant 2
CREATE INDEX idx_chats_participant_2_active 
ON chats(participant_2_id, updated_at DESC) 
WHERE is_participant_2_archived = FALSE;
```

**Validation Rules**:
- `participant1Id` ≠ `participant2Id` (no self-chats)
- `id` format: UUID v4
- `createdAt` ≤ `updatedAt` (always)
- Both participant IDs must exist in `users` table

**State Transitions** (for Chat entity):
```
[Nonexistent]
    ↓
    (User A sends first message) 
    ↓
[Active] ← (archive/unarchive)
    ↓
(Messages deleted / chat deleted)
    ↓
[Deleted] (soft delete only if needed)
```

---

### 2. Message Entity

**Purpose**: Represents a single message within a chat.

**Dart Model** (`message_model.dart`):
```dart
import 'package:json_annotation/json_annotation.dart';

part 'message_model.g.dart';

@JsonSerializable()
class Message {
  final String id;
  final String chatId;
  final String senderId;
  
  /// Base64-encoded ChaCha20-Poly1305 encrypted plaintext
  /// Never store plaintext in database
  final String encryptedContent;
  
  /// Decrypted plaintext (in-memory only, never persisted)
  @JsonKey(ignore: true)
  String? decryptedContent;
  
  final DateTime createdAt;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.encryptedContent,
    required this.createdAt,
    this.decryptedContent,
  });

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Helper: Is this message sent by current user?
  bool sentByUser(String userId) => senderId == userId;

  /// Helper: Get display timestamp (formatted for UI)
  String getDisplayTime() {
    final now = DateTime.now();
    if (createdAt.day == now.day && createdAt.month == now.month) {
      return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
    return '${createdAt.month}/${createdAt.day}';
  }
}
```

**PostgreSQL Schema**:
```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Base64 encoded encrypted content (never plaintext)
  encrypted_content TEXT NOT NULL,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Constraint: sender must be chat participant
  CONSTRAINT sender_is_participant CHECK(
    -- Validate via trigger or application logic
    TRUE -- Trigger to be implemented in migration
  )
);

-- Index for efficient message history fetch (chat + timestamp)
CREATE INDEX idx_messages_chat_created 
ON messages(chat_id, created_at DESC);

-- Index for user's sent messages (optional, for receipts/edits)
CREATE INDEX idx_messages_sender 
ON messages(sender_id, created_at DESC);
```

**Validation Rules**:
- `encryptedContent` must be non-empty Base64
- `senderId` is one of the chat's two participants
- `createdAt` must be in past (or within clock skew tolerance)
- Message text length: 1-5000 characters (post-decryption)
- No null/empty messages allowed

**State Transitions** (Message within Chat):
```
[Pending/Queued] (offline on client)
    ↓
[Sent] (timestamp confirmed)
    ↓
[Received] (recipient has downloaded - optional receipt)
    ↓
[Deleted] (soft delete only if needed)
```

---

### 3. User Entity (Existing, Reference Only)

**Reminder**: User entity already exists in `users` table from auth system.

**Fields Relevant to Chat**:
- `id`: UUID, participant identifier
- `username`: Display name in chat
- `encrypted_public_key`: For E2E encryption key exchange (added to invites flow)

---

## Relationships

```
┌─────────┐         ┌─────────┐
│ users   │         │ users   │
└────┬────┘         └────┬────┘
     │ participant_1_id  │ participant_2_id
     │                   │
     └─────────┬─────────┘
               │
            ┌──▼──┐
            │chats│ (1:1 between any two users)
            └──┬──┘
               │ chat_id
               │
            ┌──▼────────┐
            │ messages  │ (N messages per chat)
            └───────────┘
```

**Cascade Rules**:
- Delete `users` → Delete all their chats → Delete all messages ✓ (ON DELETE CASCADE)
- Delete `chats` → Delete all messages in that chat ✓ (ON DELETE CASCADE)
- Archive does NOT cascade (user choice)

---

## Computed Fields / View Models

These are NOT persisted but derived for UI rendering.

**ChatListItem** (ViewModel for chat list display):
```dart
class ChatListItem {
  final String id;
  final String otherUserName;  // Friend's display name
  final String? lastMessagePreview;  // "Alice: Hey, how are you?"
  final DateTime? lastMessageTime;  // From last message
  final bool isArchived;  // User-specific
  final bool hasUnreadMessages;  // Could be added in Phase 2
  
  // Derived from: Chat + Message + User
}
```

**MessageBubbleData** (ViewModel for message display):
```dart
class MessageBubbleData {
  final String id;
  final String senderName;  // "Alice" or "You"
  final String decryptedText;  // Displayed to user
  final DateTime createdAt;
  final bool isSentByCurrentUser;  // Right vs left bubble
  final String displayTime;  // "14:30" or "Mar 15"
  
  // Derived from: Message + User + decryption
}
```

---

## Validation & Constraints Summary

| Field | Type | Validation | Notes |
|-------|------|-----------|-------|
| Chat.id | UUID | gen_random_uuid() | Primary key |
| Chat.participant_1_id | UUID | UNIQUE + NOT NULL, NOT self | Foreign key to users |
| Chat.participant_2_id | UUID | UNIQUE + NOT NULL, NOT self | Foreign key to users |
| Chat.isParticipant1Archived | Boolean | DEFAULT FALSE | Per-user state |
| Chat.isParticipant2Archived | Boolean | DEFAULT FALSE | Per-user state |
| Chat.updatedAt | Timestamp | >= createdAt | Triggers on message received |
| Message.id | UUID | gen_random_uuid() | Primary key |
| Message.chatId | UUID | NOT NULL | MUST exist in chats |
| Message.senderId | UUID | NOT NULL | MUST be chat participant |
| Message.encryptedContent | Text | Base64, NOT empty | ChaCha20 encrypted |
| Message.createdAt | Timestamp | NOT NULL | Client-generated timestamp |

---

## Phase 2 Extensions (Not in MVP)

- **Message.edited_at**: Track message edits (requires new table)
- **Message.deleted_at**: Soft delete with user-can-restore window
- **ChatMember.typing_indicator**: Real-time "X is typing..." (WebSocket only)
- **Message.read_at**: Read receipts (per-message per-user)
- **Chat.muted_until**: Notification muting (per-user preference)

All Phase 2 extensions preserve backwards compatibility with Message/Chat schema.
