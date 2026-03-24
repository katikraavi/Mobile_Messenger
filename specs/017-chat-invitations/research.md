# Research & Design Decisions: Chat Invitations

**Date**: 2026-03-15 | **Feature**: [017-chat-invitations](./spec.md)

## Overview

This document consolidates all research findings, design decisions, and rationale for the Chat Invitations feature. All NEEDS CLARIFICATION markers have been resolved through stakeholder clarification and best-practices research.

---

## Decision 1: Notification Strategy

**Decision**: In-app badge + push notification (no email)

**Rationale**:
- Push notifications ensure users are notified promptly even when app is closed
- In-app badge provides persistent visual indicator within the app
- Email adds complexity without proportional user value (users check app frequently)
- Email-based approvals create security concerns (token in email body)
- Aligns with modern mobile UX patterns (badge + push standard)

**Alternatives Considered**:
- ❌ Email notifications only: Slower user journey, higher friction
- ❌ In-app badge only: Misses users not in app; low discoverability
- ❌ In-app + push + email: Unnecessary complexity; email rarely needed for immediate actions

**Implementation Impact**:
- Requires integration with push notification service (Firebase Cloud Messaging for Android, APNs for iOS)
- In-app UI must show badge count on Invitations tab
- Push payload must include sender name + "You have a new invitation" message
- Deep link to Invitations tab from push notification

**Testing Strategy**:
- Unit: Badge count calculation on new invites
- UI: Badge visibility when new invite received
- Integration: Push notification delivery + deep link routing

---

## Decision 2: Invitation Expiration Policy

**Decision**: No automatic expiration (invites persist indefinitely)

**Rationale**:
- Simplifies data model: no `expires_at` timestamp needed
- Reduces operational complexity: no background job for cleanup
- Aligns with user behavior: users control their inbox
- Chat creation automatically removes invite (no orphaned data)
- Decline action explicitly removes (user agency)

**Alternatives Considered**:
- ❌ 7-day expiration: Creates UX friction if user away for a week
- ❌ 30-day expiration: Still requires cleanup job; arbitrary cutoff
- ❌ Custom expiration per sender: Overly complex; unintuitive

**Implementation Impact**:
- Schema: No `expires_at` column in ChatInvite table
- No background jobs required
- Simpler SQL queries (no expiration filters)
- Manual deletion via accept/decline only

**Testing Strategy**:
- Unit: Verify invites never expire (no time-based removal)
- Integration: Verify 100+ year-old invites still appear in list

---

## Decision 3: UI Navigation & Access Pattern

**Decision**: Dedicated "Invitations" tab in main app navigation bar

**Rationale**:
- First-class feature deserves tab-level prominence
- Badge on tab provides always-visible notification
- Dedicated screen simplifies UX (no context switching)
- Establishes mental model: "Invitations" is a core feature
- Reduces navigation complexity vs. nested within Contacts

**Alternatives Considered**:
- ❌ Floating action button: Doesn't show pending count; less discoverable
- ❌ Within Contacts section: Buries feature; reduces visibility
- ❌ Bottom sheet modal: Feels temporary; invites are persistent
- ✓ Dedicated tab: Best balance of visibility + dedicated UX

**Implementation Impact**:
- Modify main navigation (BottomNavigationBar or equivalent)
- Add new tab icon (envelope/mail style)
- Create InvitationsScreen as primary view
- Add nested SendInvitePickerScreen for discovery
- Tab bar styling must show badge with unread count
- Platform: Both Android and iOS support bottom navigation bar

**Testing Strategy**:
- UI: Tab visibility and navigation
- UI: Badge display on tab when new invites received
- Integration: Full user flow through tab

---

## Design Pattern: Mutual Invitations

**Pattern**: Both invites can coexist independently

**Scenario**: User A sends invite to User B while User B sends invite to User A

**Handling**:
1. Both ChatInvite records created independently in database
2. If User A accepts first: Chat created, User A → User B invite marked "accepted"
3. User B's pending invite (from A) automatically removed/marked "chat_exists" when chat created
4. Same if User B accepts first

**Rationale**:
- Simpler database constraint (no unique index on sender+recipient pairs)
- Better UX: accept early without worrying about other person's invite
- Automatic cleanup when chat created via `ChatCreated` event

**Implementation**: Accept endpoint checks: if chat already exists with this user, remove all mutual invites

---

## Design Pattern: Duplicate Prevention

**Pattern**: User cannot have 2+ pending invites to same recipient

**Rationale**:
- Prevents inbox clutter from duplicate sends
- Simpler UX: one action per user, not multiple invites
- Better data integrity

**Constraint**: Database unique index on `(sender_id, recipient_id, status='pending')`

**Handling**:
- sendInvite endpoint checks: if pending invite exists from same sender to same recipient, return 409 Conflict
- Allow multiple invites if first one is already declined/accepted
- Error message: "You already have a pending invitation to this user"

---

## Design Pattern: Preventing Invites to Contacts

**Pattern**: Block invites to users already in a chat

**Rationale**:
- Redundant: if they're chatting, they don't need an invite
- Better UX: prevents confusion about what happens on accept
- Aligns with user mental model

**Check**: sendInvite endpoint queries: if Chat exists with `participants = [sender, recipient]`, return 400 Bad Request

**Error Message**: "You're already chatting with this user"

---

## Design Pattern: Self-Invite Prevention

**Pattern**: Block sender_id == recipient_id

**Rationale**:
- Nonsensical: user cannot invite themselves
- Data integrity: meaningless ChatInvite record
- Better UX: error caught at UI level before backend

**Implementation**: 
- Frontend validation: disable send button if selected user is current user
- Backend validation: if sender_id == recipient_id, return 400 Bad Request

---

## Frontend State Management Strategy

**Pattern**: Riverpod providers for invite state

**Providers**:
- `pendingInvitesProvider`: List of received (pending) invites for current user
- `sentInvitesProvider`: List of sent invites by current user
- `inviteCountProvider`: Count of unread pending invites (for badge)
- `sendInviteMutation`: Async send action with loading/success/error states
- `acceptInviteMutation`: Async accept action
- `declineInviteMutation`: Async decline action

**Caching**: 
- Cache key on user_id + created_at timestamp
- Invalidate on any mutation success
- Refresh when app re-enters foreground

**Offline Behavior**:
- Show cached invites while offline
- Disable action buttons (send/accept/decline)
- Queue action mutations; execute when reconnected

---

## Backend API Endpoints

**Service**: Invite REST endpoints in Serverpod

**Endpoints** (draft):
- `POST /api/invites/send` - Send new invite
- `GET /api/invites/pending` - Get pending invites for user
- `GET /api/invites/sent` - Get sent invites by user
- `POST /api/invites/{id}/accept` - Accept invite by ID
- `POST /api/invites/{id}/decline` - Decline invite by ID

**Response Format**: JSON with ChatInvite object + metadata

**Error Codes**:
- 400: Validation error (self-invite, already chatting, etc.)
- 401: Not authenticated
- 403: Not authorized to operate on invite
- 404: Invite not found
- 409: Duplicate pending invite exists

---

## Database Schema

**Table**: `chat_invites`

**Columns**:
- `id`: UUID primary key
- `sender_id`: UUID FK to users
- `recipient_id`: UUID FK to users
- `status`: ENUM ('pending', 'accepted', 'declined') - defaults to 'pending'
- `created_at`: TIMESTAMP - when invite was sent
- `updated_at`: TIMESTAMP - when status last changed
- `deleted_at`: TIMESTAMP (nullable) - soft delete for declined

**Indexes**:
- `(recipient_id, status)` - fast query of pending invites for a user
- `(sender_id, status)` - fast query of sent invites by a user
- `(sender_id, recipient_id, status)` - prevent duplicates + check for existing invite

**Unique Constraint**: No duplicate pending invites via `UNIQUE(sender_id, recipient_id) WHERE status='pending'`

---

## Security Considerations

**Authentication**:
- All endpoints require valid JWT token
- User_id extracted from JWT (no client-supplied user_id parameter)

**Authorization**:
- Users can only send invites to other users (basic check)
- Users can only view their own pending/sent invites
- Users can only accept/decline their own pending invites

**Data Exposure**:
- Invite responses include only non-sensitive data: user_id, name, avatar
- No email addresses, phone numbers in invite payloads
- No sensitive timestamps (created_at is fine; no access_logs)

**Rate Limiting**:
- Recommend per-user rate limit: 50 invites/hour (prevents spam)
- Per-recipient-user limit: 5 invites/day (prevents targeted harassment)

---

## Performance Considerations

**Query Performance**:
- Pending invites: indexed query on `(recipient_id, status='pending')` → <100ms for 10k invites
- Sent invites: indexed query on `(sender_id, status='pending')` → <100ms
- Accept: 2 operations (update invite status + create chat) → <300ms

**Frontend Performance**:
- Badge update via WebSocket real-time event → <3s latency
- Fallback to polling every 30s if WebSocket unavailable
- Pagination recommended for users with 100+ invites

---

## Testing Coverage

**Unit Tests** (30+):
- Invite validation logic
- Duplicate prevention checks
- Contact status checks
- Status transition logic
- Error handling

**Widget Tests** (20+):
- Invitations tab visibility + badge
- Send invite picker UI + user selection
- Accept/decline button actions
- Empty state rendering
- Loading states

**Integration Tests** (10+):
- Full invite send → accept → chat creation flow
- Mutual invite handling
- Duplicate prevention

**E2E Tests** (2-user):
- User A sends invite to User B
- User B receives notification + accepts
- Chat created and both users see it

---

## Known Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Invite spam from single user | Medium | High | Rate limiting per sender (50/hr) |
| Race condition: accept while already chatting | Low | Medium | Idempotent accept endpoint |
| WebSocket connection lost during accept | Medium | Low | Retry logic + polling fallback |
| Very large invite list (10k+ invites) | Low | Medium | Pagination + lazy loading |
| User deleted after sending invite | Low | Low | Graceful null checks in UI |

---

## Approval Sign-off

- **Technical Lead**: [TODO - review before Phase 1]
- **Security Review**: [TODO - encryption/auth check]
- **Product Owner**: [TODO - UX alignment]

**All NEEDS CLARIFICATION items**: ✅ **RESOLVED**

