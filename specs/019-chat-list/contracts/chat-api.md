# API Contract: Chat & Message Endpoints

**Purpose**: Define HTTP API contracts for chat list and messaging.  
**Backend**: Dart/Shelf at http://localhost:8081 (emulator: 172.31.195.26:8081)  
**Status**: Phase 1 specification  
**Format**: JSON request/response, JWT Bearer token authentication

---

## 1. Authentication

All endpoints require JWT Bearer token in `Authorization` header:
```
Authorization: Bearer <jwt_token>
```

Token obtained from `/api/auth/login` endpoint (existing flow).

---

## 2. GET /api/chats

**Purpose**: Fetch all active chats for current user, sorted by most recent.

**Request**:
```http
GET /api/chats HTTP/1.1
Host: localhost:8081
Authorization: Bearer eyJhbGc...
```

**Query Parameters**:
| Name | Type | Required | Notes |
|------|------|----------|-------|
| `limit` | integer | No | Default: 50, Max: 100 |
| `before_cursor` | ISO 8601 timestamp | No | For pagination (before this timestamp) |
| `include_archived` | boolean | No | Default: false (only active chats) |

**Response** (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "participant_1_id": "alice-uuid",
      "participant_2_id": "bob-uuid",
      "created_at": "2026-03-10T14:30:00Z",
      "updated_at": "2026-03-15T09:45:00Z",
      "is_participant_1_archived": false,
      "is_participant_2_archived": false,
      "last_message": {
        "id": "msg-uuid-001",
        "chat_id": "550e8400-e29b-41d4-a716-446655440001",
        "sender_id": "bob-uuid",
        "encrypted_content": "ChaCha20PolyBase64EncodedString==",
        "created_at": "2026-03-15T09:45:00Z"
      }
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440002",
      "participant_1_id": "alice-uuid",
      "participant_2_id": "charlie-uuid",
      "created_at": "2026-03-12T10:00:00Z",
      "updated_at": "2026-03-14T16:20:00Z",
      "is_participant_1_archived": false,
      "is_participant_2_archived": false,
      "last_message": {
        "id": "msg-uuid-002",
        "chat_id": "550e8400-e29b-41d4-a716-446655440002",
        "sender_id": "alice-uuid",
        "encrypted_content": "AnotherEncryptedBase64==",
        "created_at": "2026-03-14T16:20:00Z"
      }
    }
  ]
}
```

**Response** (400 Bad Request):
```json
{
  "success": false,
  "error": "Invalid limit parameter"
}
```

**Response** (401 Unauthorized):
```json
{
  "success": false,
  "error": "Missing or invalid token"
}
```

**Implementation Notes**:
- Query: `SELECT * FROM chats WHERE (participant_1_id = $1 AND is_participant_1_archived = FALSE) OR (participant_2_id = $1 AND is_participant_2_archived = FALSE) ORDER BY updated_at DESC LIMIT $2`
- Omit `last_message` if chat is empty (null)
- Return most recent 50 chats by default

---

## 3. GET /api/chats/{chatId}/messages

**Purpose**: Fetch message history for a specific chat.

**Request**:
```http
GET /api/chats/550e8400-e29b-41d4-a716-446655440001/messages HTTP/1.1
Host: localhost:8081
Authorization: Bearer eyJhbGc...
```

**Query Parameters**:
| Name | Type | Required | Notes |
|------|------|----------|-------|
| `limit` | integer | No | Default: 20, Max: 100 |
| `before_cursor` | ISO 8601 timestamp | No | Load messages created before this time |

**Response** (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "msg-uuid-001",
      "chat_id": "550e8400-e29b-41d4-a716-446655440001",
      "sender_id": "bob-uuid",
      "encrypted_content": "ChaCha20PolyBase64EncodedString==",
      "created_at": "2026-03-15T09:45:00Z"
    },
    {
      "id": "msg-uuid-002",
      "chat_id": "550e8400-e29b-41d4-a716-446655440001",
      "sender_id": "alice-uuid",
      "encrypted_content": "AnotherEncryptedBase64==",
      "created_at": "2026-03-15T09:30:00Z"
    }
  ],
  "has_more": true
}
```

**Response** (403 Forbidden):
```json
{
  "success": false,
  "error": "User is not a participant in this chat"
}
```

**Response** (404 Not Found):
```json
{
  "success": false,
  "error": "Chat not found"
}
```

**Implementation Notes**:
- Verify current user is a participant in the chat (security)
- Return messages ordered newest first (DESC by created_at)
- `has_more`: true if there are older messages available
- Max 100 messages per request

---

## 4. POST /api/chats/{chatId}/messages

**Purpose**: Send a message in a chat.

**Request**:
```http
POST /api/chats/550e8400-e29b-41d4-a716-446655440001/messages HTTP/1.1
Host: localhost:8081
Authorization: Bearer eyJhbGc...
Content-Type: application/json

{
  "encrypted_content": "ChaCha20PolyBase64EncodedString==",
  "created_at": "2026-03-15T09:50:00Z"
}
```

**Request Body**:
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `encrypted_content` | string | Yes | Base64-encoded ChaCha20-Poly1305 ciphertext |
| `created_at` | ISO 8601 | Yes | Client-generated timestamp (for clock skew tolerance) |

**Response** (201 Created):
```json
{
  "success": true,
  "data": {
    "id": "msg-uuid-003",
    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
    "sender_id": "alice-uuid",
    "encrypted_content": "ChaCha20PolyBase64EncodedString==",
    "created_at": "2026-03-15T09:50:00Z"
  }
}
```

**Response** (400 Bad Request):
```json
{
  "success": false,
  "error": "encrypted_content must be non-empty Base64"
}
```

**Response** (403 Forbidden):
```json
{
  "success": false,
  "error": "User is not a participant in this chat"
}
```

**Implementation Notes**:
- Verify sender is a participant in the chat
- Max encrypted content size: 10KB
- Idempotency: Use (chat_id + sender_id + created_at) as key to prevent duplicates on retry
- Broadcast to WebSocket subscribers (if connected)
- Update `chats.updated_at` to current time (bumps chat to top of list)

---

## 5. PUT /api/chats/{chatId}/archive

**Purpose**: Archive a chat for current user.

**Request**:
```http
PUT /api/chats/550e8400-e29b-41d4-a716-446655440001/archive HTTP/1.1
Host: localhost:8081
Authorization: Bearer eyJhbGc...
Content-Type: application/json

{
  "archived": true
}
```

**Request Body**:
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `archived` | boolean | Yes | true to archive, false to unarchive |

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "is_participant_1_archived": false,
    "is_participant_2_archived": true,
    "archived_by_current_user": true
  }
}
```

**Response** (403 Forbidden):
```json
{
  "success": false,
  "error": "User is not a participant in this chat"
}
```

**Implementation Notes**:
- Update `is_participant_1_archived` or `is_participant_2_archived` based on current user
- Other participant's archive state unaffected
- Archived chat persists messages (not deleted)
- Return both archive flags so client knows overall state

---

## 6. WebSocket: /ws/messages

**Purpose**: Real-time message delivery via persistent WebSocket connection.

**Connection**:
```
GET /ws/messages HTTP/1.1
Host: localhost:8081
Upgrade: websocket
Authorization: Bearer eyJhbGc...
```

**Event: New Message** (server → client):
```json
{
  "type": "message",
  "data": {
    "id": "msg-uuid-004",
    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
    "sender_id": "bob-uuid",
    "encrypted_content": "ChaCha20PolyBase64EncodedString==",
    "created_at": "2026-03-15T09:55:00Z"
  }
}
```

**Event: Chat Archive Change** (server → client):
```json
{
  "type": "chat_archived",
  "data": {
    "chat_id": "550e8400-e29b-41d4-a716-446655440001",
    "user_id": "bob-uuid",
    "archived": true
  }
}
```

**Event: Connection Established** (server → client):
```json
{
  "type": "connection_established",
  "data": {
    "user_id": "alice-uuid",
    "timestamp": "2026-03-15T10:00:00Z"
  }
}
```

**Implementation Notes**:
- Server broadcasts new message to both participants if connected
- Authenticated via JWT in URL or query parameter
- Auto-reconnect on client side (exponential backoff)
- Heartbeat ping/pong every 30 seconds to detect stale connections
- Messages received while disconnected delivered via polling on reconnect

---

## Error Response Format (Standard)

All errors follow this format:

```json
{
  "success": false,
  "error": "Human-readable error message",
  "error_code": "INVALID_PARAMETER",
  "timestamp": "2026-03-15T10:00:00Z"
}
```

**Common Error Codes**:
- `INVALID_PARAMETER`: Request validation failed
- `UNAUTHORIZED`: Missing/invalid token
- `FORBIDDEN`: Permission denied (not participant)
- `NOT_FOUND`: Resource doesn't exist
- `DUPLICATE_MESSAGE`: Idempotency key conflict
- `INTERNAL_ERROR`: Server error

---

## Pagination Example

**First request** (no cursor):
```
GET /api/chats/{chatId}/messages?limit=20
```

**Response includes**:
```json
{
  "data": [/* 20 messages */],
  "has_more": true
}
```

**Next request** (use oldest message's timestamp as cursor):
```
GET /api/chats/{chatId}/messages?limit=20&before_cursor=2026-03-15T09:30:00Z
```

Continues until `has_more: false`.

---

## Versioning & Compatibility

- API version: v1
- Future changes will increment version path: `/api/v2/chats`
- Deprecated endpoints will return 410 Gone
