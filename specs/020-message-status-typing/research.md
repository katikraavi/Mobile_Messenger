# Phase 0 Research: Messaging with Status Indicators and Typing Notifications

**Date**: 2026-03-16  
**Status**: RESOLVING "NEEDS CLARIFICATION" from plan.md  
**Scope**: Encryption strategy, real-time patterns, message persistence approach

---

## 1. Message Encryption Strategy

### Question
Should message content be encrypted end-to-end (E2E), at-rest only, or in-transit only per Constitution I (Security-First)?

### Options Evaluated

#### Option A: End-to-End Encryption (MOST SECURE)
- **What**: Messages encrypted on sender device before transmission, decrypted only on recipient device
- **How**: 
  - Sender encrypts message with recipient's public key (or shared session key)
  - Encrypted blob sent to backend and stored in PostgreSQL
  - Backend never has plaintext access to message content
  - Recipient receives encrypted blob and decrypts with private key
- **Pros**:
  - Maximum security - backend can't read messages even if compromised
  - Complies with Constitution I (Security-First) in strongest form
  - Privacy advantage for users
  - Backend storage is inherently protected
- **Cons**:
  - More complex implementation (key exchange, PKI setup)
  - Harder to search/index messages (stored as encrypted blobs)
  - Message editing/deletion requires re-encryption coordination
  - Requires crypto library on both frontend and backend
- **Crypto Library**: `cryptography` package (Dart) - already available
- **When to Use**: If privacy/security is primary concern

#### Option B: At-Rest Encryption (PRACTICAL SECURITY)
- **What**: Messages sent plaintext over TLS, stored encrypted in database, encrypted in memory
- **How**:
  - Frontend sends message over HTTPS/WSS (encrypted in transit)
  - Backend receives plaintext, encrypts with server-side key, stores encrypted blob
  - Backend decrypts on retrieval, serves plaintext over WSS to recipient
  - Server manages single encryption key (not per-user keys)
- **Pros**:
  - Simpler implementation than E2E
  - Database breach doesn't expose messages (if key is secure)
  - Can still search/index messages (if needed)
  - Good balance of security and usability
  - Complies with Constitution I (acceptable implementation)
- **Cons**:
  - Backend has temporary plaintext access during processing
  - Key management critical - one compromised key exposes all messages
  - Developer access to messages possible
- **When to Use**: MVP phase - balances security and development speed

#### Option C: Transit-Only Encryption (STATUS QUO)
- **What**: Messages encrypted only in transit (HTTPS/WSS), stored plaintext in DB
- **How**:
  - Frontend sends over WSS connection (encrypted by TLS)
  - Backend stores plaintext in PostgreSQL (encrypted via PostgreSQL native encryption)
  - Messages served plaintext to clients over WSS
- **Pros**:
  - Simplest implementation
  - Full text search and indexing works
  - Easiest to debug
- **Cons**:
  - Does NOT meet Constitution I Security-First principle
  - Database breaches expose all message content
  - VIOLATION of project constitution
- **When to Use**: NOT ACCEPTABLE - violates security principle

### Decision: OPTION B - At-Rest Encryption

**Rationale**:
- Meets Constitution I (Security-First) requirement for encrypted persistence
- Provides strong security without E2E complexity for MVP
- Complies with project security scope (messages encrypted at rest)
- Can be upgraded to E2E in future without API changes
- Practical balance for development speed vs. security

**Implementation Details**:
- Use `cryptography` package for AES-256-GCM encryption
- Store encryption key in environment variable (backend deployment secret)
- Each message encrypted with random IV (initialization vector)
- IV stored with encrypted message for decryption
- Backend decrypts before serving to client over WSS/HTTPS

---

## 2. Real-Time Communication Pattern

### Question
Use WebSockets or HTTP polling for typing indicators and message status updates?

### Options Evaluated

#### Option A: WebSockets (REAL-TIME)
- **What**: Persistent bidirectional connection between frontend and backend
- **How**:
  - Frontend establishes persistent WebSocket connection on app start
  - Backend maintains connection per connected client
  - Typing events, message status, and deliveries sent immediately
  - Connection stays open for app lifetime
- **Pros**:
  - True real-time (<100ms latency for typing, status)
  - Efficient - single connection, no polling overhead
  - Natural fit for bi-directional communication
  - Typing indicator shows with minimal delay
  - Status updates immediate (almost no latency)
- **Cons**:
  - More complex implementation (connection lifecycle)
  - Backend must manage connections per client
  - Requires graceful disconnection handling
  - Mobile: connection drops on network switch, needs reconnection logic
- **Performance**: <100ms latency typical, <50ms possible
- **When to Use**: Best user experience

#### Option B: HTTP Polling (FALLBACK)
- **What**: Frontend periodically polls backend for new messages and status updates
- **How**:
  - Frontend calls GET /api/messages every 1-2 seconds
  - Backend returns new messages and status changes since last poll
  - Typing indicator sent as HTTP endpoint, polled separately
  - No persistent connection
- **Pros**:
  - Simpler implementation than WebSockets
  - No connection management needed
  - Works over any HTTP proxy/firewall
  - Easier mobile network transitions
- **Cons**:
  - Higher latency (poll interval = 1000-2000ms typical)
  - More bandwidth usage (polling empty responses)
  - Battery drain on mobile (continuous polling)
  - Typing indicator delayed by poll interval
  - Poor UX for real-time features
  - Does NOT meet SC-004: "1 second" typing indicator requirement
- **Performance**: 500-2000ms latency (NOT acceptable)
- **When to Use**: Fallback only if WebSocket unavailable

#### Option C: Hybrid - WebSocket with Polling Fallback
- **What**: Use WebSocket when available, fall back to polling if unavailable
- **How**:
  - Try WebSocket first on app start
  - If WebSocket fails (firewall, network), use polling fallback
  - Automatic detection and fallback logic
  - Same API contract for both transports
- **Pros**:
  - Best reliability and UX
  - Works on networks that block WebSocket
  - Automatic fallback transparent to app
  - Can leverage both strengths
- **Cons**:
  - More complex implementation (dual transport handling)
  - Must test both code paths
  - Potential race conditions between transports
- **When to Use**: Production robustness

### Decision: OPTION C - Hybrid (WebSocket Primary, Polling Fallback)

**Rationale**:
- Meets SC-004 requirement (<1s typing indicator) via WebSocket
- Reliable fallback for constrained networks via polling
- Best user experience and reliability
- Complexity manageable with socket.io-like library

**Implementation Details**:
- Primary: WebSocket connection for real-time events
- Fallback: HTTP polling if WebSocket unavailable (5s retry interval)
- Events sent via WebSocket:
  - `message.new` - new message received
  - `message.status` - status changed (sent/delivered/read)
  - `typing.start` - user started typing
  - `typing.stop` - user stopped typing
  - `message.edited` - message was edited
  - `message.deleted` - message was deleted
- Polling endpoint: GET /api/events?since=<timestamp> for events since last poll

---

## 3. Message Persistence & Edit/Delete Strategy

### Question
How to handle message edits and deletes while maintaining consistency and audit trail?

### Approaches Analyzed

#### Approach A: Soft Delete with Version History (RECOMMENDED)
- **What**: Never truly delete messages, mark as deleted, keep edit history
- **How**:
  - `messages` table has `is_deleted` boolean flag
  - `message_edits` table stores previous versions (messageId, editNumber, content, editedAt)
  - Original message always queryable (filtered by is_deleted in UI)
  - Deleted messages show "[message deleted]" placeholder
  - Edit history retrievable for audit
- **Schema**:
  ```sql
  messages (
    id, chatId, senderId, recipientId, content,
    status, createdAt, editedAt, deletedAt, is_deleted
  )
  message_edits (
    id, messageId, editNumber, previousContent, newContent, editedAt
  )
  ```
- **Pros**:
  - Audit trails preserved
  - Can undelete if needed (admin feature future)
  - Consistent with spec requirement: "[message deleted]" placeholder
  - Recovery possible
- **Cons**:
  - Database grows with history
  - Slight query complexity for "show all non-deleted"
- **When to Use**: MVP and beyond (supports audit trail)

#### Approach B: True Delete (NOT RECOMMENDED)
- **What**: Physically remove deleted messages from database
- **How**:
  - DELETE FROM messages WHERE id = X
  - Cascade deletes all associated records
  - No placeholder shown to recipient
- **Pros**:
  - Simpler queries
  - Database stays smaller
- **Cons**:
  - VIOLATES SPEC: "placeholder indicating message was deleted (not just silently removed)"
  - No audit trail
  - Recipients see message silently disappear
  - Contradicts user story requirement
- **When to Use**: NOT ACCEPTABLE per spec

### Decision: APPROACH A - Soft Delete with Version History

**Rationale**:
- Directly supports spec requirement for "[message deleted]" placeholder
- Provides audit trail for security compliance
- Allows future admin features (undelete, edit history display)
- Aligns with production messaging systems

**Implementation Details**:
- Edit: Store previous content in message_edits, update existing row, set editedAt
- Delete: Set is_deleted=true, set deletedAt=now()
- Query: Always filter WHERE is_deleted=false (except admin audit queries)
- UI Display: Show "[message deleted]" when is_deleted=true
- Both operations trigger WebSocket events to connected clients

---

## 4. Typing Indicator Timeout & State Management

### Question
How to implement reliable typing indicator with timeout on backend and frontend?

### Strategy
**Timeout Value**: 3 seconds per spec (FR-006)

**Backend Implementation**:
- Typing indicator NOT persisted in database (ephemeral real-time state)
- In-memory state per user per chat: `{userId, chatId, typingStartedAt, timeout}`
- When user sends "typing.start" event:
  - Record starting timestamp
  - Set 3-second timer
  - Broadcast to other user immediately via WebSocket
- Timer expires after 3s:
  - Clear state
  - Broadcast "typing.stop" to other user
- When user sends "typing.stop" OR sends message:
  - Clear state immediately
  - Broadcast "typing.stop"
  - Cancel timeout

**Frontend Implementation**:
- User types in input field
- After 100ms of no changes, send "typing.start" if not already sent
- Continue typing, no additional sends
- After 3s of no changes, don't send "typing.stop" (backend handles it)
- When user sends message, send "typing.stop" immediately
- On receiving "typing.stop", hide indicator immediately

**Prevents Duplicates**: (SC-010)
- Key: `{userId, chatId}` - only one active typing indicator per user per chat
- Multiple updates to same key don't create duplicates, update same indicator

---

## 5. Message Status Progression

### Question
How to implement message status progression (pending → sent → delivered → read)?

### Status Flow

```
pending (local, not yet sent)
    ↓ (send request to backend succeeds)
sent (backend received)
    ↓ (recipient device connected, message synced)
delivered (recipient has message)
    ↓ (recipient views message, viewport visible OR chat opened)
read (recipient marked as read)
```

### Implementation Details

**Frontend - Sender**:
1. User clicks send
2. Message created with status `pending` in local optimistic UI
3. Send HTTP/WebSocket request to backend
4. If success: update local status to `sent`
5. Listen for WebSocket `message.status` events
6. When status becomes `delivered`: update UI checkmark
7. When status becomes `read`: update UI to blue checkmark

**Backend - Tracking Status**:
- Accept message → create row with status `sent`
- When recipient connects/syncs → check if they should have message → status `delivered` via WebSocket
- When recipient marks as read (viewport visible OR explicit read action) → status `read` via WebSocket

**Frontend - Recipient**:
1. Receive WebSocket `message.new` event with message data
2. Display in chat history with status `delivered`
3. If message in viewport: mark as read immediately
4. Send `message.read` WebSocket event
5. Backend updates status to `read`, broadcasts back to sender

### Pessimistic vs. Optimistic Handling
- **Optimistic** (current approach): Update UI immediately, confirm with backend
- **Fallback**: If network request fails, revert status to `pending` with retry button

---

## Summary of Decisions

| Topic | Decision | Rationale |
|-------|----------|-----------|
| **Encryption** | At-rest (Option B) | Meets Constitution I, practical for MVP, can upgrade to E2E later |
| **Real-time Transport** | WebSocket + polling fallback (Option C) | Meets <1s typing requirement, reliable fallback |
| **Edit/Delete Strategy** | Soft delete with history (Approach A) | Meets spec requirement for placeholder, audit trail, recovery |
| **Typing Timeout** | 3s server-side, 100ms frontend debounce | Per spec, prevents duplicates |
| **Status Progression** | pending → sent → delivered → read | Clear user experience, real-time updates |

## Ready for Phase 1

✅ All "NEEDS CLARIFICATION" items resolved  
✅ Technical decisions documented  
✅ Ready to proceed to data-model.md, contracts/, quickstart.md

