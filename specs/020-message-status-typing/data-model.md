# Data Model: Messaging Feature

**Date**: 2026-03-16  
**Status**: Phase 1 Output  
**Source**: [research.md](research.md) decisions

---

## Entity Definitions

### 1. Message

**Purpose**: Represents a single message sent from one user to another in a chat.

**Attributes**:
- `id` (UUID, Primary Key): Unique identifier for this message
- `chatId` (UUID, Foreign Key → chats.id): Which chat this message belongs to
- `senderId` (UUID, Foreign Key → users.id): User who sent the message
- `recipientId` (UUID, Foreign Key → users.id): User who receives the message (for 1-to-1)
- `content` (TEXT, ENCRYPTED): Message body text (encrypted at rest per Constitution I)
- `status` (ENUM: pending/sent/delivered/read): Current delivery status
- `createdAt` (TIMESTAMP): When message was created (millisecond precision)
- `editedAt` (TIMESTAMP, nullable): When last edited (null if never edited)
- `deletedAt` (TIMESTAMP, nullable): When soft-deleted (null if not deleted)
- `isDeleted` (BOOLEAN): Whether this message is soft-deleted

**Relationships**:
- Belongs to Chat (chatId)
- Sent by User (senderId)
- Received by User (recipientId)
- Has many MessageStatus entries (if multi-user future)
- Has many MessageEdit entries (edit history)

**Constraints**:
- `content` must not be empty
- `status` defaults to 'sent' on creation
- `isDeleted` defaults to false
- Foreign keys cascade on chat/user delete

**Indexes**:
- `(chatId, createdAt DESC)` - Fetch messages for chat in order
- `(senderId, createdAt DESC)` - Fetch messages from specific user
- `(recipientId, status)` - Find unread messages by recipient

**Sample Query**:
```sql
SELECT * FROM messages 
WHERE chatId = $1 
  AND isDeleted = false 
ORDER BY createdAt DESC 
LIMIT 50 OFFSET 0
```

---

### 2. MessageStatus

**Purpose**: Tracks the delivery and read status of a message (primarily for 1-to-1, extensible for groups).

**Attributes**:
- `id` (UUID, Primary Key): Unique identifier
- `messageId` (UUID, Foreign Key → messages.id): Which message
- `recipientId` (UUID, Foreign Key → users.id): For whom (recipient in 1-to-1, any member in groups)
- `status` (ENUM: sent/delivered/read): Current status for this recipient
- `deliveredAt` (TIMESTAMP, nullable): When status changed to delivered
- `readAt` (TIMESTAMP, nullable): When status changed to read
- `updatedAt` (TIMESTAMP): Last update time for this status record

**Relationships**:
- Belongs to Message (messageId)
- References User (recipientId)

**Constraints**:
- Unique constraint: `(messageId, recipientId)` - one status record per message-recipient pair
- `status` defaults to 'sent'
- `deliveredAt` set when status becomes 'delivered'
- `readAt` set when status becomes 'read'

**Indexes**:
- `(recipientId, status, updatedAt)` - Find unread messages for user
- `(messageId)` - Get all status records for a message

**Sample Query**:
```sql
SELECT *
FROM message_status
WHERE recipientId = $1 AND status != 'read'
ORDER BY updatedAt DESC
```

---

### 3. MessageEdit

**Purpose**: Maintains audit trail and history of message edits.

**Attributes**:
- `id` (UUID, Primary Key): Unique identifier
- `messageId` (UUID, Foreign Key → messages.id): Which message was edited
- `editNumber` (INTEGER): Sequential edit number (1, 2, 3...)
- `previousContent` (TEXT, ENCRYPTED): Content before this edit
- `editedAt` (TIMESTAMP): When this edit occurred

**Relationships**:
- Belongs to Message (messageId)

**Constraints**:
- `editNumber` starts at 1 (after original message)
- `previousContent` encrypted at rest per Constitution I
- Cannot be updated or deleted (immutable audit trail)

**Indexes**:
- `(messageId, editNumber DESC)` - Get edit history for a message
- `(messageId)` - Get all edits for a message

**Sample Query**:
```sql
SELECT * FROM message_edits
WHERE messageId = $1
ORDER BY editNumber DESC
```

---

### 4. TypingIndicator

**Purpose**: Real-time ephemeral state for users currently typing (NOT PERSISTED in database).

**Note**: This is in-memory server state ONLY, not stored in PostgreSQL.

**Attributes** (in-memory):
- `userId` (UUID): Who is typing
- `chatId` (UUID): In which chat
- `typingStartedAt` (TIMESTAMP): When typing started
- `timeout` (Timer): JavaScript timeout handle for auto-stop

**Lifecycle**:
- Created: User sends "typing.start" event
- Active: Maintained in memory, broadcast to other user via WebSocket
- Expired: Timer fires after 3 seconds, auto-stop sent
- Cleared: When user sends "typing.stop" or sends a message

**Data Structure** (Backend pseudocode):
```
typingIndicators: Map<string, TypingState> = {}
// Key: "{userId}:{chatId}"
// Value: { startedAt, timeout }

on typing.start:
  key = "${userId}:${chatId}"
  if (key not in typingIndicators) {
    typingIndicators[key] = { startedAt: now, timeout: null }
    broadcast to chat members
  }
  clear existing timeout
  set new timeout(3000ms) {
    broadcast typing.stop
    delete typingIndicators[key]
  }

on typing.stop OR send message:
  clear timeout
  delete typingIndicators[key]
  broadcast typing.stop
```

---

## Database Schema (DDL)

### Create Messages Table

```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content BYTEA NOT NULL,  -- Encrypted message content
  status VARCHAR(20) NOT NULL DEFAULT 'sent' CHECK (status IN ('pending','sent','delivered','read')),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  edited_at TIMESTAMP,
  deleted_at TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at_ms BIGINT GENERATED ALWAYS AS (EXTRACT(EPOCH FROM created_at) * 1000) STORED
);

CREATE INDEX idx_messages_chat_created ON messages(chat_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id, created_at DESC);
CREATE INDEX idx_messages_recipient_status ON messages(recipient_id, status, created_at DESC);
```

### Create Message Status Table

```sql
CREATE TABLE message_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','delivered','read')),
  delivered_at TIMESTAMP,
  read_at TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(message_id, recipient_id)
);

CREATE INDEX idx_message_status_recipient ON message_status(recipient_id, status, updated_at DESC);
```

### Create Message Edits Table

```sql
CREATE TABLE message_edits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  edit_number INTEGER NOT NULL,
  previous_content BYTEA NOT NULL,  -- Encrypted previous content
  edited_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(message_id, edit_number)
);

CREATE INDEX idx_message_edits_message ON message_edits(message_id, edit_number DESC);
```

---

## Data Flow Examples

### Example 1: Send Message

```
User (Frontend)
  |
  v
1. Create message locally: {chatId, recipientId, content, status: 'pending'}
                         |
                         v (POST /api/messages)
                      
Server (Backend)
  |
  v
2. Receive message, validate JWT token, get senderId
  |
  v
3. Encrypt content with server key
  |
  v
4. Insert into messages table:
   - id: generated UUID
   - chatId, senderId, recipientId from auth/payload
   - content: encrypted blob
   - status: 'sent' (immediately after backend receives)
   - created_at: now()
  |
  v
5. Create message_status record: {messageId, recipientId, status: 'sent', updated_at: now()}
  |
  v
6. Broadcast via WebSocket: {event: 'message.new', message: {...}, status: 'sent'}
  |
  v
User (Recipient Client)
  - Receives message
  - Displays in chat with status 'sent'
  - Marks as 'delivered' (received)
  - Sends WebSocket event: {event: 'message.read', messageId}
  |
  v
Server
  - Updates message_status: status = 'read', read_at = now()
  - Broadcasts back to sender: {event: 'message.status', messageId, status: 'read'}
  |
  v
User (Sender Client)
  - Updates message status indicator to blue (read)
```

### Example 2: Edit Message

```
User (Sender)
  |
  v
1. Long-press message, select "Edit"
2. Modify content
3. Send update: PUT /api/messages/{messageId} {newContent: "..."}
  |
  v
Server
  |
  v
1. Validate auth (verify sender_id in JWT = message.sender_id)
2. Retrieved existing message from DB
3. Create message_edit entry:
   - messageId: {messageId}
   - editNumber: (SELECT MAX(edit_number) + 1 FROM message_edits WHERE messageId = ...)
   - previousContent: (encrypt old content)
   - edited_at: now()
4. Update messages row:
   - content: (encrypt new content)
   - edited_at: now()
5. Broadcast WebSocket: {event: 'message.edited', messageId, newContent, editedAt}
  |
  v
Both Users
  - Receive update
  - Display message with "(edited)" label
  - Timestamp shows "edited at [time]"
```

### Example 3: Delete Message

```
User (Sender)
  |
  v
1. Long-press message, select "Delete"
2. Confirm deletion
3. Send: DELETE /api/messages/{messageId}
  |
  v
Server
  |
  v
1. Validate auth (verify sender_id = current user)
2. Update messages row:
   - isDeleted: true
   - deletedAt: now()
3. Broadcast WebSocket: {event: 'message.deleted', messageId}
  |
  v
Both Users
  - Receive update
  - Display "[message deleted]" placeholder instead of content
  - Message still in history (not removed completely)
```

---

## Encryption Strategy (Implementation Detail)

Per Constitution I requirement and research.md decision for at-rest encryption:

**Library**: `cryptography` package (Dart)

**Algorithm**: AES-256-GCM (Authenticated encryption)

**Key Storage**:
- Server maintains single encryption key in environment variable: `MESSAGE_ENCRYPTION_KEY`
- Key rotated during deployments (old messages still decryptable if needed)
- Frontend doesn't store encryption key (server-side encryption model)

**Encryption Process**:
```
plaintext = "Hello, how are you?"
nonce = crypto.random(12 bytes)  // Random initialization vector
ciphertext = AES256GCM.encrypt(plaintext, key: MESSAGE_ENCRYPTION_KEY, nonce: nonce)
stored_value = nonce || ciphertext || tag  // Concatenate for storage
```

**Decryption Process**:
```
stored_value = fetch from DB
nonce = stored_value[0:12]
ciphertext_and_tag = stored_value[12:]
plaintext = AES256GCM.decrypt(ciphertext_and_tag, key, nonce)
```

**Storage Format**: Encrypted blob stored as BYTEA in PostgreSQL

