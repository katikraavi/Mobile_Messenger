# Chat Invitations - Developer API Documentation

## Overview

Complete API reference for the Chat Invitations feature. This document covers all REST endpoints, request/response formats, error handling, and integration examples.

---

## Base URL

```
http://localhost:8080/api
```

All requests require JWT authentication token in `Authorization: Bearer {token}` header.

---

## Endpoints

### 1. Send Chat Invitation

**Endpoint**: `POST /invites/send`

**Description**: Send a new chat invitation to a user

**Authentication**: Required (JWT token)

**Request Body**:
```json
{
  "recipientId": "user-uuid-string"
}
```

**Response** (201 Created):
```json
{
  "id": "invite-uuid-string",
  "senderId": "sender-uuid",
  "recipientId": "recipient-uuid",
  "status": "pending",
  "createdAt": "2026-03-15T10:30:00Z",
  "updatedAt": "2026-03-15T10:30:00Z",
  "deletedAt": null
}
```

**Error Responses**:
- `400 Bad Request` - Validation error (self-invite, already chatting, etc)
- `401 Unauthorized` - No valid JWT token
- `404 Not Found` - User not found
- `409 Conflict` - Pending invitation already exists

**cURL Example**:
```bash
curl -X POST http://localhost:8080/api/invites/send \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"recipientId": "user-id-here"}'
```

**Flutter/HTTP Example**:
```dart
final response = await http.post(
  Uri.parse('http://localhost:8080/api/invites/send'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'recipientId': userId}),
);
```

---

### 2. Get Pending Invitations

**Endpoint**: `GET /invites/pending`

**Description**: Get all pending invitations for current user

**Authentication**: Required (JWT token)

**Query Parameters**:
- `limit` (optional, default: 100): Number of results to return
- `offset` (optional, default: 0): Pagination offset

**Response** (200 OK):
```json
[
  {
    "id": "invite-uuid-1",
    "senderId": "sender-uuid",
    "recipientId": "current-user-id",
    "status": "pending",
    "createdAt": "2026-03-15T10:30:00Z",
    "updatedAt": "2026-03-15T10:30:00Z",
    "deletedAt": null,
    "senderName": "John Doe",
    "senderAvatarUrl": "https://..."
  },
  {
    "id": "invite-uuid-2",
    ...
  }
]
```

**Error Responses**:
- `401 Unauthorized` - No valid JWT token

**cURL Example**:
```bash
curl http://localhost:8080/api/invites/pending \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

### 3. Get Sent Invitations

**Endpoint**: `GET /invites/sent`

**Description**: Get all invitations sent by current user

**Authentication**: Required (JWT token)

**Query Parameters**:
- `limit` (optional, default: 100): Number of results to return
- `offset` (optional, default: 0): Pagination offset

**Response** (200 OK):
```json
[
  {
    "id": "invite-uuid-1",
    "senderId": "current-user-id",
    "recipientId": "recipient-uuid",
    "status": "pending",
    "createdAt": "2026-03-15T10:30:00Z",
    "updatedAt": "2026-03-15T10:30:00Z",
    "deletedAt": null
  },
  {
    "id": "invite-uuid-2",
    "senderId": "current-user-id",
    "recipientId": "another-uuid",
    "status": "accepted",
    "createdAt": "2026-03-14T15:20:00Z",
    "updatedAt": "2026-03-14T15:25:00Z",
    "deletedAt": null
  }
]
```

---

### 4. Get Pending Invitation Count

**Endpoint**: `GET /invites/pending/count`

**Description**: Get count of pending invitations (lightweight)

**Authentication**: Required (JWT token)

**Response** (200 OK):
```json
{
  "count": 3
}
```

---

### 5. Accept Invitation

**Endpoint**: `POST /invites/{id}/accept`

**Description**: Accept a pending invitation and create chat

**Authentication**: Required (JWT token)

**Path Parameters**:
- `id` (required): Invitation UUID

**Request Body**: Empty `{}`

**Response** (200 OK):
```json
{
  "inviteId": "invite-uuid",
  "status": "accepted",
  "createdChatId": "chat-uuid",
  "message": "Invitation accepted and chat created"
}
```

**Error Responses**:
- `400 Bad Request` - Invalid invitation ID
- `401 Unauthorized` - Not authenticated
- `403 Forbidden` - You're not the recipient
- `404 Not Found` - Invitation not found

**cURL Example**:
```bash
curl -X POST http://localhost:8080/api/invites/invite-id-here/accept \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

### 6. Decline Invitation

**Endpoint**: `POST /invites/{id}/decline`

**Description**: Decline a pending invitation

**Authentication**: Required (JWT token)

**Path Parameters**:
- `id` (required): Invitation UUID

**Request Body**: Empty `{}`

**Response** (200 OK):
```json
{
  "inviteId": "invite-uuid",
  "status": "declined",
  "message": "Invitation declined"
}
```

**Error Responses**:
- `400 Bad Request` - Invalid invitation ID or already final status
- `401 Unauthorized` - Not authenticated
- `403 Forbidden` - You're not the recipient
- `404 Not Found` - Invitation not found

---

## Data Models

### ChatInvite Object

```typescript
{
  id: string;              // UUID
  senderId: string;        // UUID of invitation sender
  recipientId: string;     // UUID of invitation recipient
  status: string;          // 'pending' | 'accepted' | 'declined'
  createdAt: string;       // ISO 8601 timestamp
  updatedAt: string;       // ISO 8601 timestamp
  deletedAt: string | null; // Soft delete timestamp (null if not deleted)
  
  // Optional - included in GET responses
  senderName?: string;
  senderAvatarUrl?: string;
}
```

---

## Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | Success | GET /invites/pending returns list |
| 201 | Created | POST /invites/send creates invitation |
| 400 | Bad Request | Self-invite, validation error |
| 401 | Unauthorized | Missing or invalid JWT token |
| 403 | Forbidden | User doesn't have permission |
| 404 | Not Found | Invalid invitation or user ID |
| 409 | Conflict | Duplicate pending invitation |
| 500 | Server Error | Database or internal error |
| 503 | Service Unavailable | Database connection issue |

---

## Authentication

All endpoints require JWT token in header:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Token is obtained during login and contains `userId` in the payload.

---

## Error Handling

### Standard Error Response

```json
{
  "error": true,
  "message": "User not found",
  "statusCode": 404
}
```

### Common Errors

**Self-Invite**:
```json
{
  "error": true,
  "message": "Cannot invite yourself",
  "statusCode": 400
}
```

**Already Chatting**:
```json
{
  "error": true,
  "message": "Users already have a chat",
  "statusCode": 400
}
```

**Duplicate Pending**:
```json
{
  "error": true,
  "message": "Pending invitation already exists",
  "statusCode": 409
}
```

---

## Rate Limiting

Current limits (per user):
- `POST /invites/send`: 10 requests per minute
- `POST /invites/{id}/accept`: 20 requests per minute
- `POST /invites/{id}/decline`: 20 requests per minute
- `GET /invites/*`: 100 requests per minute

Responses include rate limit headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1710500400
```

---

## Pagination

For endpoints returning lists, pagination uses offset/limit:

```
GET /invites/pending?limit=20&offset=40
```

This returns items 40-60 (page 3 with 20 items per page).

Recommended:
- `limit`: 10-50 (default 50)
- `offset`: Start at 0

---

## Examples

### Complete Flow: Send, View, Accept

**1. Send Invitation**:
```bash
curl -X POST http://localhost:8080/api/invites/send \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"recipientId": "user-2-id"}'

# Response: {"id": "invite-1", "status": "pending", ...}
```

**2. View Pending**:
```bash
curl http://localhost:8080/api/invites/pending \
  -H "Authorization: Bearer TOKEN"

# Response: [{"id": "invite-1", ...}, ...]
```

**3. Accept**:
```bash
curl -X POST http://localhost:8080/api/invites/invite-1/accept \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'

# Response: {"inviteId": "invite-1", "status": "accepted", ...}
```

---

## Webhooks / Notifications

When an invitation is created, a push notification is sent:

```json
{
  "type": "chat_invitation",
  "title": "Chat Invitation",
  "body": "New chat invitation from John Doe",
  "data": {
    "deepLink": "messenger://invitations?tab=pending",
    "inviteId": "invite-uuid",
    "senderName": "John Doe"
  }
}
```

---

## Performance Tuning

### Query Optimization

- Pending invites query uses index on (recipient_id, status)  
- Sent invites query uses index on (sender_id, status)
- Expected response time: < 100ms for paginated requests

### Caching

- Invite count: Cache for 30 seconds
- Invitation lists: Cache with 1-minute TTL
- Implement cache invalidation on mutation

### Pagination Recommendations

- Frontend: Load 20 items initially
- Implement lazy loading for additional pages
- Show loading spinner while fetching

---

## Changelog

### Version 1.0 (March 15, 2026)

- Initial release
- 6 core endpoints
- Full CRUD operations for invitations
- Push notification integration

---

Generated: March 15, 2026  
Feature: Chat Invitations (017-chat-invitations)  
Status: Production Ready
