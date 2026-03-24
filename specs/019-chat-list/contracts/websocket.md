# Contract: WebSocket Real-Time Messaging

**Purpose**: Define WebSocket protocol for real-time message delivery.  
**Endpoint**: `ws://localhost:8081/ws/messages` (or `wss://` for production)  
**Authentication**: JWT Bearer token in URL query param or Authorization header  

---

## Connection

### Establish Connection

**Request**:
```
GET /ws/messages HTTP/1.1
Host: localhost:8081
Upgrade: websocket
Connection: Upgrade
Authorization: Bearer eyJhbGc...
```

**Alternative**: Pass token in query parameter (for browser compatibility):
```
GET /ws/messages?token=eyJhbGc... HTTP/1.1
```

### Connection Response (server → client)

On successful connection:
```json
{
  "type": "connection_established",
  "data": {
    "user_id": "alice-uuid",
    "message": "Connected to real-time messaging",
    "timestamp": "2026-03-15T10:00:00Z"
  }
}
```

### Connection Errors

**401 Unauthorized** (invalid/missing token):
```
Connection rejected with WebSocket close code 4001
Reason: "Unauthorized: Invalid token"
```

**Server closed connection**:
```
Close code 1000 (normal) or 1011 (server error)
Client should auto-reconnect with exponential backoff
```

---

## Event Types

### 1. Message Event (server → client)

Sent when a message is posted to any chat the user participates in.

```json
{
  "type": "message",
  "data": {
    "id": "msg-uuid-001",
    "chat_id": "chat-uuid-001",
    "sender_id": "bob-uuid",
    "encrypted_content": "ChaCha20PolyBase64EncodedString==",
    "created_at": "2026-03-15T10:05:00Z",
    "sender_username": "bob"
  },
  "timestamp": "2026-03-15T10:05:00Z"
}
```

**Handler Logic** (client):
1. Identify which chat the message belongs to
2. Decrypt `encrypted_content` using chat's shared key
3. If user is viewing that chat → append message to conversation UI
4. If user is in chat list → bump chat to top, show message preview
5. If user is elsewhere → show notification badge

### 2. Chat Archive Event (server → client)

Sent when a participant archives or unarchives a chat.

```json
{
  "type": "chat_archived",
  "data": {
    "chat_id": "chat-uuid-001",
    "user_id": "bob-uuid",
    "archived": true,
    "performer_username": "bob"
  },
  "timestamp": "2026-03-15T10:06:00Z"
}
```

**Handler Logic** (client):
1. If action performed by OTHER user → update chat's archive flag display
2. If current user archived → remove from main list
3. Don't auto-close if notification badge exists

### 3. Typing Indicator (server → client) [Phase 2]

Sent when another participant starts/stops typing.

```json
{
  "type": "user_typing",
  "data": {
    "chat_id": "chat-uuid-001",
    "user_id": "bob-uuid",
    "username": "bob",
    "is_typing": true
  },
  "timestamp": "2026-03-15T10:07:00Z"
}
```

**Handler Logic** (client):
1. If viewing the chat → show "bob is typing..." below message input
2. Clear after 3 seconds if no new typing event received

### 4. Read Receipt (server → client) [Phase 2]

Sent when a participant marks messages as read.

```json
{
  "type": "messages_read",
  "data": {
    "chat_id": "chat-uuid-001",
    "reader_id": "alice-uuid",
    "last_message_id": "msg-uuid-005",
    "read_at": "2026-03-15T10:08:00Z"
  },
  "timestamp": "2026-03-15T10:08:00Z"
}
```

**Handler Logic** (client):
1. Mark messages up to `last_message_id` as read
2. Update checkmark icons in UI

### 5. User Presence (server → client) [Phase 2]

Sent when another participant comes online/offline.

```json
{
  "type": "user_status",
  "data": {
    "user_id": "bob-uuid",
    "status": "online",
    "last_seen": "2026-03-15T10:09:00Z"
  },
  "timestamp": "2026-03-15T10:09:00Z"
}
```

---

## Server Broadcast Logic

### When Message Arrives

```
1. Parse message (validate encrypted_content, sender, chat_id)
2. Store in database
3. Find all participants in chat
4. For each participant:
   - If connected to WebSocket → broadcast message event
   - Update chat.updated_at → triggers list re-sort
5. Return 201 Created to HTTP client
```

### Participant Broadcast

**Scenario**: Alice sends message in chat with Bob.

- **If both connected to WebSocket**:
  - Alice: Sees her message appear immediately (optimistic + server confirmation)
  - Bob: Receives message event from server
  
- **If Bob not connected**:
  - Message stored in database
  - Bob receives on reconnect (via HTTP polling `/api/chats/{id}/messages`)

---

## Heartbeat & Keep-Alive

### Ping/Pong (WebSocket control frames)

Server sends ping every 30 seconds:
```json
{
  "type": "ping",
  "data": { "timestamp": "2026-03-15T10:10:00Z" }
}
```

Client must respond with pong:
```json
{
  "type": "pong",
  "data": { "timestamp": "2026-03-15T10:10:00Z" }
}
```

**Timeout Handling**:
- If no pong received within 5 seconds → connection considered stale
- Server closes connection with code 1002 (protocol error)
- Client auto-reconnects

---

## Message Ordering

**Guarantee**: Messages ordered by `created_at` timestamp (server clock).

- All events include `timestamp` (server-generated, not client)
- Client must NOT rely on receipt order for ordering
- Use `created_at` field to sort messages in UI

```dart
// Correct
messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

// Wrong: Don't trust arrival order
```

---

## Error Handling

### Exception Event (server → client)

```json
{
  "type": "error",
  "data": {
    "code": "INVALID_MESSAGE",
    "message": "Encrypted content too large (>10KB)",
    "related_chat_id": "chat-uuid-001"
  },
  "timestamp": "2026-03-15T10:11:00Z"
}
```

**Client Response**:
- Log error
- Show user-friendly alert if critical
- Don't disconnect unless instructed

---

## Reconnect Strategy

**Exponential Backoff**:
```
Attempt 1: Reconnect immediately
Attempt 2: Wait 1 second
Attempt 3: Wait 2 seconds
Attempt 4: Wait 4 seconds
Attempt 5: Wait 8 seconds
Max: Cap at 30 seconds between retries
```

**Trigger Reconnect**:
- Connection closed (WebSocket close event)
- No pong received for 5 seconds
- User brings app to foreground (manual trigger)

**State Sync on Reconnect**:
1. Reconnect to WebSocket
2. Fetch `/api/chats` to get latest chat list
3. For each open chat, fetch `/api/chats/{id}/messages` to fill gaps
4. Resume normal operation

---

## Example: Complete Message Flow

**Time: T=0s**

Alice types "Hello Bob" and hits send.

```
[Client A] → POST /api/chats/chat-001/messages
{
  "encrypted_content": "ChaCha20...",
  "created_at": "2026-03-15T10:15:00Z"
}
```

**Time: T=0.1s**

Backend stores message, broadcasts via WebSocket to Bob (if connected).

```
[Server] → [WebSocket Bob]
{
  "type": "message",
  "data": { "id": "msg-123", "sender_id": "alice", ... }
}
```

**Time: T=0.2s**

Bob's client receives event, decrypts message, renders in UI.

```
[Client B UI] Shows message: "Hello Bob" in left bubble
```

**Time: T=0.15s**

Backend responds to Alice's POST with 201 Created.

```
[Server] → [Client A]
{
  "success": true,
  "data": { "id": "msg-123", ... }
}
```

**Time: T=0.2s**

Alice's client receives confirmation, marks message as sent (green checkmark).

```
[Client A UI] Shows message: "Hello Bob" with sent ✓ indicator
```

**Result**: End-to-end latency ~200ms (within <2s requirement).

---

## Future Extensions (No Breaking Changes)

- **Message Reactions**: New event type `reaction_added` (emoji count on message)
- **Calls**: New event type `call_started` with WebRTC link
- **File Sharing**: Message with `attachment_urls` field
- **Group Chats**: Support N-way participant chats (extend per-chat)

All backward compatible if new fields are optional.
