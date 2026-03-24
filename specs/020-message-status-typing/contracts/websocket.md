# WebSocket Message Contracts

**Date**: 2026-03-16  
**Protocol**: JSON-RPC over WebSocket (WSS recommended)  
**Base URL**: `wss://localhost:8081/ws/messages` (or fallback HTTP polling)

---

## Connection & Authentication

### Client → Server: Connect Request

```json
{
  "type": "connection",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "chatId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Fields**:
- `type` (string): Always "connection" for initial handshake
- `token` (string): JWT authentication token (Bearer token)
- `userId` (string, UUID): Current user's ID
- `chatId` (string, UUID): Which chat to subscribe to

**Response** (Server → Client):

```json
{
  "type": "connected",
  "status": "ok",
  "userId": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "chatId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-03-16T14:30:00.000Z"
}
```

**Error Response**:

```json
{
  "type": "error",
  "status": "unauthorized",
  "message": "Invalid token",
  "code": 401
}
```

---

## Message Events

### Server → Client: New Message Received

**Event**: `message.new`

```json
{
  "type": "message.new",
  "message": {
    "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "chatId": "550e8400-e29b-41d4-a716-446655440000",
    "senderId": "c73d034d-43cd-4623-8406-8b500015a3a6",
    "recipientId": "d83e7d12-bd4c-461a-93c4-8b500015b2c8",
    "content": "Hey, how are you?",
    "status": "delivered",
    "createdAt": "2026-03-16T14:30:00.000Z",
    "editedAt": null,
    "deletedAt": null,
    "isDeleted": false
  },
  "timestamp": "2026-03-16T14:30:00.100Z"
}
```

**Fields**:
- `type` (string): Always "message.new"
- `message` (object): Full message object (see data-model.md)
- `timestamp` (string, ISO8601): Server timestamp when event generated

---

### Client → Server: Send Message

**Event**: `message.send`

```json
{
  "type": "message.send",
  "message": {
    "chatId": "550e8400-e29b-41d4-a716-446655440000",
    "recipientId": "d83e7d12-bd4c-461a-93c4-8b500015b2c8",
    "content": "Hey, how are you?"
  },
  "clientId": "client-123456"
}
```

**Fields**:
- `type` (string): Always "message.send"
- `message` (object): Message to send
  - `chatId` (string, UUID): Which chat
  - `recipientId` (string, UUID): Recipient user ID
  - `content` (string): Message text (non-empty)
- `clientId` (string): Client-generated ID for deduplication (optional)

**Server Response** - Success:

```json
{
  "type": "message.sent",
  "message": {
    "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "chatId": "550e8400-e29b-41d4-a716-446655440000",
    "senderId": "c73d034d-43cd-4623-8406-8b500015a3a6",
    "recipientId": "d83e7d12-bd4c-461a-93c4-8b500015b2c8",
    "content": "Hey, how are you?",
    "status": "sent",
    "createdAt": "2026-03-16T14:30:00.000Z",
    "editedAt": null,
    "deletedAt": null,
    "isDeleted": false
  },
  "clientId": "client-123456",
  "timestamp": "2026-03-16T14:30:00.100Z"
}
```

**Server Response** - Error:

```json
{
  "type": "error",
  "message": "Message content cannot be empty",
  "code": 400,
  "clientId": "client-123456"
}
```

---

## Message Status Events

### Server → Client: Message Status Changed

**Event**: `message.status`

```json
{
  "type": "message.status",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "status": "read",
  "deliveredAt": null,
  "readAt": "2026-03-16T14:30:05.000Z",
  "timestamp": "2026-03-16T14:30:05.100Z"
}
```

**Fields**:
- `type` (string): Always "message.status"
- `messageId` (string, UUID): Which message
- `status` (string): New status (sent/delivered/read)
- `deliveredAt` (string, ISO8601, nullable): When delivered
- `readAt` (string, ISO8601, nullable): When read
- `timestamp` (string, ISO8601): Server timestamp

---

### Client → Server: Mark Message as Read

**Event**: `message.read`

```json
{
  "type": "message.read",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "readAt": "2026-03-16T14:30:05.000Z"
}
```

**Fields**:
- `type` (string): Always "message.read"
- `messageId` (string, UUID): Which message to mark as read
- `readAt` (string, ISO8601): Client timestamp when read

**Server Response**:

```json
{
  "type": "message.status",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "status": "read",
  "readAt": "2026-03-16T14:30:05.000Z",
  "timestamp": "2026-03-16T14:30:05.100Z"
}
```

---

## Message Edit Events

### Client → Server: Edit Message

**Event**: `message.edit`

```json
{
  "type": "message.edit",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "newContent": "Hey, how ARE you?",
  "timestamp": "2026-03-16T14:30:10.000Z"
}
```

**Fields**:
- `type` (string): Always "message.edit"
- `messageId` (string, UUID): Which message to edit
- `newContent` (string): New message text (non-empty)
- `timestamp` (string, ISO8601): Client timestamp

**Server Response** - Success:

```json
{
  "type": "message.edited",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "newContent": "Hey, how ARE you?",
  "editedAt": "2026-03-16T14:30:10.500Z",
  "editNumber": 1,
  "timestamp": "2026-03-16T14:30:10.600Z"
}
```

**Server Response** - Error:

```json
{
  "type": "error",
  "message": "You can only edit your own messages",
  "code": 403,
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479"
}
```

### Server → Client: Message Edited Notification (to other user)

```json
{
  "type": "message.edited",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "newContent": "Hey, how ARE you?",
  "editedAt": "2026-03-16T14:30:10.500Z",
  "editNumber": 1,
  "editedBy": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "timestamp": "2026-03-16T14:30:10.600Z"
}
```

---

## Message Delete Events

### Client → Server: Delete Message

**Event**: `message.delete`

```json
{
  "type": "message.delete",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "timestamp": "2026-03-16T14:30:15.000Z"
}
```

**Fields**:
- `type` (string): Always "message.delete"
- `messageId` (string, UUID): Which message to delete
- `timestamp` (string, ISO8601): Client timestamp

**Server Response** - Success:

```json
{
  "type": "message.deleted",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "deletedAt": "2026-03-16T14:30:15.500Z",
  "timestamp": "2026-03-16T14:30:15.600Z"
}
```

### Server → Client: Message Deleted Notification (to other user)

```json
{
  "type": "message.deleted",
  "messageId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "deletedAt": "2026-03-16T14:30:15.500Z",
  "deletedBy": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "timestamp": "2026-03-16T14:30:15.600Z"
}
```

---

## Typing Indicator Events

### Client → Server: Start Typing

**Event**: `typing.start`

```json
{
  "type": "typing.start",
  "userId": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "chatId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-03-16T14:30:20.000Z"
}
```

**Fields**:
- `type` (string): Always "typing.start"
- `userId` (string, UUID): Who is typing
- `chatId` (string, UUID): In which chat
- `timestamp` (string, ISO8601): Client timestamp

**No Server Response** (fire-and-forget)

### Server → Client: Typing Start Notification (to other user in chat)

```json
{
  "type": "typing.start",
  "userId": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "userName": "Alice",
  "chatId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-03-16T14:30:20.100Z"
}
```

**Fields**:
- `type` (string): Always "typing.start"
- `userId` (string, UUID): Who is typing
- `userName` (string): Display name for UI "[Alice is typing...]"
- `chatId` (string, UUID): In which chat
- `timestamp` (string, ISO8601): Server timestamp

---

### Client → Server: Stop Typing (optional; server auto-stops after 3s)

**Event**: `typing.stop`

```json
{
  "type": "typing.stop",
  "userId": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "chatId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-03-16T14:30:25.000Z"
}
```

**No Server Response** (fire-and-forget)

### Server → Client: Typing Stop Notification (to other user in chat)

```json
{
  "type": "typing.stop",
  "userId": "c73d034d-43cd-4623-8406-8b500015a3a6",
  "chatId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-03-16T14:30:25.100Z"
}
```

---

## Connection Management

### Server → Client: Ping (Keep-alive)

```json
{
  "type": "ping",
  "timestamp": "2026-03-16T14:30:30.000Z"
}
```

### Client → Server: Pong (Keep-alive response)

```json
{
  "type": "pong",
  "timestamp": "2026-03-16T14:30:30.050Z"
}
```

### Server → Client: Disconnect/Timeout

```json
{
  "type": "disconnected",
  "reason": "Server shutdown" OR "Timeout",
  "reconnect": true,
  "timestamp": "2026-03-16T14:30:35.000Z"
}
```

---

## Error Response Format (Generic)

Any error that doesn't require response queue:

```json
{
  "type": "error",
  "code": 400,
  "message": "Invalid request format",
  "details": {
    "field": "content",
    "reason": "Cannot be empty"
  },
  "timestamp": "2026-03-16T14:30:40.000Z"
}
```

**Codes**:
- `400`: Bad request (validation error)
- `401`: Unauthorized (invalid token)
- `403`: Forbidden (permission denied)
- `404`: Not found (message doesn't exist)
- `409`: Conflict (concurrent edit/delete)
- `500`: Server error

