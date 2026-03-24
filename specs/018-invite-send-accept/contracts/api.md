# API Contracts: Invitation Feature

**Status**: Design specification (implements FR-001 through FR-014)  
**Base URL**: `http://localhost:8081/api` (or production equivalent)  
**Authentication**: Bearer token in `Authorization` header

---

## Shared Elements

### Authentication Header
```
Authorization: Bearer <JWT_TOKEN>
```

All endpoints require valid JWT. Token must come from user who is making the request.

### Error Response Format
```json
{
  "error": "<error_code>",
  "message": "<human_readable_message>",
  "details": {
    "field": "optional_additional_context"
  }
}
```

**Common Error Codes**:
- `unauthorized`: Missing or invalid Bearer token (401)
- `forbidden`: User lacks permission for operation (403)
- `not_found`: Resource does not exist (404)
- `duplicate_invitation`: Invitation already exists (409)
- `invalid_user`: Recipient does not exist (400)
- `self_invitation`: Cannot send invitation to yourself (400)
- `already_blocked`: Recipient has blocked sender (400)
- `invalid_status_transition`: Operation not valid for current status (400)

---

## Endpoint 1: Create Invitation (Send Invitation)

**Endpoint**: `POST /invites`  
**Purpose**: Send an invitation to another user (FR-001, FR-002)  
**Authentication**: Required  
**Rate Limit**: 10 requests per minute per user

### Request

```http
POST /api/invites HTTP/1.1
Authorization: Bearer <token>
Content-Type: application/json

{
  "receiverId": "b8465fd4-56e0-4f97-9a4f-9e2cb862d444"
}
```

**Request Field Validation**:
- `receiverId`: Required, must be valid UUID of existing user
- Cannot be same as sender's ID (FR-011)
- Receiver must not be in sender's blocked list

### Response

**Success (201 Created)**:
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

**Errors**:
- `400 Bad Request`: Missing receiverId or self-invitation
- `404 Not Found`: Receiver user does not exist
- `409 Conflict`: Pending invitation already exists to this user (FR-010)
- `400 Already Blocked`: Receiver has blocked sender
- `401 Unauthorized`: Invalid or missing token

### Implementation Notes

- **Idempotency**: Not idempotent; multiple calls create multiple invitations (if not duplicate)
- **Database**: INSERT into invites table; generated UUID for id
- **Triggers**: 
  - Send notification to recipient (if notification system available)
  - Log invitation creation event

---

## Endpoint 2: Get Pending Invitations (Recipient's View)

**Endpoint**: `GET /users/:userId/invites/pending`  
**Purpose**: Fetch invitations received by the user that are still pending (FR-008)  
**Authentication**: Required  
**Notes**: User can only fetch their own pending invitations

### Request

```http
GET /api/users/b8465fd4-56e0-4f97-9a4f-9e2cb862d444/invites/pending HTTP/1.1
Authorization: Bearer <token>
```

**Query Parameters** (optional):
- `limit`: Number of results (default: 100, max: 500)
- `offset`: Pagination offset (default: 0)
- `sort`: "newest" or "oldest" (default: "newest")

### Response

**Success (200 OK)**:
```json
[
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
]
```

**Empty Response (200 OK, No Pending)**:
```json
[]
```

**Errors**:
- `401 Unauthorized`: Invalid token
- `403 Forbidden`: Trying to fetch another user's pending invites
- `404 Not Found`: userId does not exist

### Performance

- **Query**: `SELECT * FROM invites WHERE receiver_id = ? AND status = 'pending' ORDER BY created_at DESC`
- **Index**: `idx_invites_receiver_status` (receiver_id, status)
- **Expected Time**: <200ms for typical user

---

## Endpoint 3: Get Sent Invitations (Sender's View)

**Endpoint**: `GET /users/:userId/invites/sent`  
**Purpose**: Fetch invitations sent by the user (FR-009)  
**Authentication**: Required  
**Notes**: User can only fetch their own sent invitations

### Request

```http
GET /api/users/bfd3a96a-ab36-442c-9b4e-276050b87678/invites/sent HTTP/1.1
Authorization: Bearer <token>
```

**Query Parameters** (optional):
- `limit`: Number of results (default: 100, max: 500)
- `offset`: Pagination offset (default: 0)
- `status`: Filter by status ("pending", "accepted", "rejected", "canceled" or omit for all)
- `sort`: "newest" or "oldest" (default: "newest")

### Response

**Success (200 OK)**:
```json
[
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
]
```

**Errors**:
- `401 Unauthorized`: Invalid token
- `403 Forbidden`: Trying to fetch another user's sent invites
- `404 Not Found`: userId does not exist

### Performance

- **Query**: `SELECT * FROM invites WHERE sender_id = ? ORDER BY created_at DESC`
- **Index**: `idx_invites_sender_status` (sender_id, status)
- **Expected Time**: <200ms

---

## Endpoint 4: Accept Invitation

**Endpoint**: `POST /invites/:invitationId/accept`  
**Purpose**: Recipient accepts an invitation; triggers chat creation (FR-005, FR-006)  
**Authentication**: Required  
**Notes**: Only the invitation recipient can accept

### Request

```http
POST /api/invites/7540c74f-5bd3-469d-9a46-82090d624aa7/accept HTTP/1.1
Authorization: Bearer <token>
Content-Type: application/json

{}
```

### Response

**Success (200 OK)**: Returns updated invitation + newly created chat

```json
{
  "invitation": {
    "id": "7540c74f-5bd3-469d-9a46-82090d624aa7",
    "senderId": "bfd3a96a-ab36-442c-9b4e-276050b87678",
    "senderName": "alice",
    "senderAvatarUrl": null,
    "recipientId": "b8465fd4-56e0-4f97-9a4f-9e2cb862d444",
    "recipientName": "bob",
    "recipientAvatarUrl": null,
    "status": "accepted",
    "createdAt": "2026-03-15T13:47:18.522694Z",
    "respondedAt": "2026-03-15T13:48:30.123456Z"
  },
  "chat": {
    "id": "chat-uuid-here",
    "participantIds": ["bfd3a96a-ab36-442c-9b4e-276050b87678", "b8465fd4-56e0-4f97-9a4f-9e2cb862d444"],
    "createdAt": "2026-03-15T13:48:30.123456Z"
  }
}
```

**Errors**:
- `400 Bad Request`: Invitation status is not "pending"
- `403 Forbidden`: Current user is not the invitation recipient
- `404 Not Found`: Invitation does not exist
- `401 Unauthorized`: Invalid token

### Implementation Notes

- **Atomicity**: Accept invitation + Create chat MUST be atomic transaction
- **Blocking Check**: Re-validate recipient has not blocked sender before accepting
- **Race Condition**: If sender cancels concurrently, database determines winner (Q2: timestamp-based)

---

## Endpoint 5: Reject Invitation

**Endpoint**: `POST /invites/:invitationId/reject` or `POST /invites/:invitationId/decline`  
**Purpose**: Recipient rejects an invitation (FR-007)  
**Authentication**: Required  
**Notes**: Only the invitation recipient can reject

### Request

```http
POST /api/invites/7540c74f-5bd3-469d-9a46-82090d624aa7/decline HTTP/1.1
Authorization: Bearer <token>
Content-Type: application/json

{}
```

### Response

**Success (200 OK)**:
```json
{
  "id": "7540c74f-5bd3-469d-9a46-82090d624aa7",
  "senderId": "bfd3a96a-ab36-442c-9b4e-276050b87678",
  "senderName": "alice",
  "senderAvatarUrl": null,
  "recipientId": "b8465fd4-56e0-4f97-9a4f-9e2cb862d444",
  "recipientName": "bob",
  "recipientAvatarUrl": null,
  "status": "rejected",
  "createdAt": "2026-03-15T13:47:18.522694Z",
  "respondedAt": "2026-03-15T13:48:30.123456Z"
}
```

**Errors**:
- `400 Bad Request`: Invitation status is not "pending"
- `403 Forbidden`: Current user is not the invitation recipient
- `404 Not Found`: Invitation does not exist
- `401 Unauthorized`: Invalid token

### Implementation Notes

- **Data Retention**: Rejected invitations marked for 30-day auto-deletion (Q3)
- **Reacceptance**: Once rejected, receiver cannot change status back to pending
- **Resend**: Sender can send a new (fresh) invitation after rejection

---

## Endpoint 6: Cancel Invitation

**Endpoint**: `DELETE /invites/:invitationId` or `POST /invites/:invitationId/cancel`  
**Purpose**: Sender cancels a pending invitation they sent (FR-004)  
**Authentication**: Required  
**Notes**: Only the invitation sender can cancel; only if status is "pending"

### Request

```http
DELETE /api/invites/7540c74f-5bd3-469d-9a46-82090d624aa7 HTTP/1.1
Authorization: Bearer <token>
```

### Response

**Success (200 OK)**:
```json
{
  "id": "7540c74f-5bd3-469d-9a46-82090d624aa7",
  "senderId": "bfd3a96a-ab36-442c-9b4e-276050b87678",
  "senderName": "alice",
  "senderAvatarUrl": null,
  "recipientId": "b8465fd4-56e0-4f97-9a4f-9e2cb862d444",
  "recipientName": "bob",
  "recipientAvatarUrl": null,
  "status": "canceled",
  "createdAt": "2026-03-15T13:47:18.522694Z",
  "respondedAt": null,
  "canceledAt": "2026-03-15T13:48:30.123456Z"
}
```

**Errors**:
- `400 Bad Request`: Invitation status is not "pending"
- `403 Forbidden`: Current user is not the invitation sender
- `404 Not Found`: Invitation does not exist
- `401 Unauthorized`: Invalid token

### Implementation Notes

- **Race Condition**: If recipient accepts concurrently, database determines winner (Q2: timestamp-based)
- **Recipient View**: After cancellation, invitation disappears from recipient's pending list on next fetch
- **Resend**: After cancellation, sender can send a new invitation to the same user

---

## Data Integrity Guarantees

| Guarantee | Implementation |
|-----------|----------------|
| No Duplicate Pending (FR-010) | Unique constraint: (sender_id, receiver_id) WHERE status = 'pending' |
| No Self-Invites (FR-011) | CHECK constraint: sender_id ≠ receiver_id |
| Valid State Transitions | Application-layer validation before UPDATE |
| Idempotent Reads | No side effects on GET endpoints |
| Atomic Accept+Chat (FR-006) | Database transaction spanning INSERT into invites + INSERT into chats |

---

## Rate Limiting

- **Create Invitation**: 10 requests/minute per user
- **Get Invitations**: 100 requests/minute per user
- **Accept/Reject/Cancel**: 50 requests/minute per user

**Rate Limit Headers**:
```
Ratelimit-Limit: 10
Ratelimit-Remaining: 9
Ratelimit-Reset: 1710520039
```

---

## Summary

- **6 Operations**: Create, GetPending, GetSent, Accept, Reject, Cancel
- **All operations transactional** with proper authorization checks
- **Endpoint consistency**: Same invitation DTO across all responses
- **Error handling**: Clear error codes and messages per operation
