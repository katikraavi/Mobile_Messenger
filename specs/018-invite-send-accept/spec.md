# Feature Specification: Invitation Send, Accept, Reject, and Cancel

**Feature Branch**: `018-invite-send-accept`  
**Created**: March 15, 2026  
**Status**: **✅ Ready for Planning** (All clarifications resolved)
**Input**: "Person can send invitation to another user, also cancel sent invitations. The receiver of the invitation should be able to reject or accept the invitation. Backend should track who sent and who received the invitations, so the frontend can display them accordingly."

---

## Clarifications Resolved

All critical ambiguities identified during specification have been resolved:

### Q1: Mutual Invitation Handling → **Option A: Both Coexist**
When both users send invitations to each other, both invitations are stored and displayed as separate records. Users treat each invitation independently without automatic deduplication or collision resolution.

### Q2: Race Condition Resolution → **Option C: Timestamp-Based**
When a race condition occurs (e.g., acceptance during cancellation), the database operation that commits first determines the final state. This provides deterministic, fair resolution through transaction ordering.

### Q3: Data Retention Policy → **Option B: Auto-Delete After 30 Days**
Rejected invitations are retained for 30 days, then automatically deleted. This preserves user history while preventing database bloat and allows users to re-invite after the retention period.

---

## Feature Overview

This feature allows users to initiate conversations with other users through a formal invitation system. Users can send invitations to other users, manage their sent invitations (including canceling them), and recipients can decide whether to accept or reject invitations. The system maintains complete tracking of invitation state (sender, receiver, status) enabling the frontend to display a comprehensive view of pending, accepted, and rejected invitations.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send Invitation to Another User (Priority: P1)

A user discovers another user they want to chat with and sends them an invitation. The sender should see confirmation that the invitation was sent and the recipient should be notified.

**Why this priority**: This is the core entry point of the invitation system and enables the primary user flow of initiating conversations.

**Independent Test**: Can be tested by a single user action (send invitation) and delivers core value (initiating a new conversation).

**Acceptance Scenarios**:

1. **Given** a user is viewing another user's profile or search results, **When** they tap "Send Invitation", **Then** the invitation is sent and the sender receives confirmation
2. **Given** a user has sent an invitation, **When** they view their sent invitations list, **Then** the invitation appears with status "Pending"
3. **Given** an invitation has been sent, **When** the recipient opens the app, **Then** they see a new invitation notification

---

### User Story 2 - Recipient Accepts Invitation (Priority: P1)

A user receives an invitation from another user, reviews it, and decides to accept it to start a conversation.

**Why this priority**: Accepting an invitation is the successful completion of the invitation flow and directly creates a new chat connection.

**Independent Test**: Can be tested independently with a received invitation - action (accept) creates a direct outcome (chat is created).

**Acceptance Scenarios**:

1. **Given** a user has a pending invitation in their inbox, **When** they tap "Accept", **Then** a new chat with the sender is created
2. **Given** an invitation has been accepted, **When** the sender views their chats, **Then** the new chat appears in their chat list
3. **Given** an invitation has been accepted, **When** the recipient views their chats, **Then** the new chat appears in their chat list

---

### User Story 3 - Recipient Rejects Invitation (Priority: P1)

A user receives an invitation but is not interested and rejects it, removing it from their pending invitations.

**Why this priority**: Rejection is a critical path for handling unwanted invitations and maintaining user control over their contacts.

**Independent Test**: Can be tested independently - rejection action removes invitation and doesn't create a chat.

**Acceptance Scenarios**:

1. **Given** a user has a pending invitation in their inbox, **When** they tap "Reject", **Then** the invitation is removed from their pending list
2. **Given** an invitation has been rejected, **When** the sender views their sent invitations, **Then** the invitation status changes to "Rejected"
3. **Given** an invitation has been rejected, **When** the recipient receives another invitation from the same user later, **Then** the new invitation is treated as a fresh invitation

---

### User Story 4 - Cancel Sent Invitation (Priority: P2)

A user realizes they sent an invitation to the wrong person or changes their mind, and wants to cancel a pending invitation they sent.

**Why this priority**: Cancellation is important for error recovery but is a secondary workflow compared to sending/accepting/rejecting.

**Independent Test**: Can be tested independently - cancellation removes the invitation from pending state.

**Acceptance Scenarios**:

1. **Given** a user has sent a pending invitation, **When** they view their sent invitations and tap "Cancel", **Then** the invitation is removed
2. **Given** an invitation has been canceled, **When** the recipient checks their invitations, **Then** the invitation is removed from their pending list
3. **Given** an invitation has been canceled, **When** the original sender sends a new invitation to the same user, **Then** it is treated as a new invitation

---

### User Story 5 - View Pending and Received Invitations (Priority: P2)

A user wants to see all invitations they have received (pending and past) and manage them in one place.

**Why this priority**: Visibility into pending invitations is important for users to discover connections, though the primary action is accepting/rejecting.

**Independent Test**: Can be tested by viewing the invitations list and verifying correct data is displayed.

**Acceptance Scenarios**:

1. **Given** a user has multiple pending invitations, **When** they open the invitations inbox, **Then** all pending invitations are displayed chronologically
2. **Given** a user has accepted or rejected invitations in the past, **When** they view their invitations history, **Then** past actions are recorded and visible
3. **Given** a user receives a new invitation, **When** they are on the invitations screen, **Then** the new invitation appears in real-time or after a refresh

---

### User Story 6 - View Sent Invitations (Priority: P2)

A user wants to track invitations they have sent and see their status (pending, accepted, rejected, or canceled).

**Why this priority**: Visibility into sent invitations helps users understand who they've reached out to, but is secondary to the receiving experience.

**Independent Test**: Can be tested by sending invitations and viewing the sent list with accurate status tracking.

**Acceptance Scenarios**:

1. **Given** a user has sent multiple invitations, **When** they view their sent invitations list, **Then** all sent invitations are displayed with their current status
2. **Given** an invitation status has changed (e.g., recipient accepted), **When** the sender views their sent invitations, **Then** the status is updated accordingly 
3. **Given** a user sends an invitation and then cancels it, **When** they view sent invitations, **Then** the invitation status shows "Canceled"

---

### Edge Cases

- **What happens when a user tries to send an invitation to themselves?** The system MUST prevent self-invitations.
- **What happens when a user tries to send an invitation to someone they're already chatting with?** The system MUST prevent duplicate/redundant invitations.
- **What happens if a user receives an invitation from someone they've already blocked?** The invitation SHOULD NOT appear in the user's inbox; system MUST respect blocking relationships.
- **What happens when both users send invitations to each other?** ✅ CLARIFIED: Both invitations coexist as separate records. Users see independent invitation records; both need separate actions. This keeps the system simple without complex deduplication logic and allows users to maintain separate conversation contexts.
- **What happens when a user accepts an invitation while the sender has canceled it?** ✅ CLARIFIED: Use timestamp-based resolution. Whichever operation completes first takes effect (database transaction semantics ensure deterministic outcome). This provides fair and transparent conflict resolution.
- **How long are rejected invitations retained?** ✅ CLARIFIED: Auto-delete after 30 days. Rejected invitations are kept for 30 days then automatically removed. This balances history preservation with database cleanliness, and users can re-invite after 30 days without old rejection history cluttering the UI.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a user to send an invitation to another user by providing the recipient's identifier or selecting from search/profile results
- **FR-002**: System MUST generate a unique invitation record storing sender ID, receiver ID, creation timestamp, and current status
- **FR-003**: System MUST support invitation status states: "Pending", "Accepted", "Rejected", and "Canceled"
- **FR-004**: System MUST allow an invitation sender to cancel a "Pending" invitation at any time before the recipient acts
- **FR-005**: System MUST allow an invitation recipient to accept a "Pending" invitation, which transitions status to "Accepted"
- **FR-006**: System MUST create a new chat when an invitation is accepted, making both users visible to each other
- **FR-007**: System MUST allow an invitation recipient to reject a "Pending" invitation, which transitions status to "Rejected"
- **FR-008**: System MUST display all invitations received by a user, organized by status (pending vs. resolved)
- **FR-009**: System MUST display all invitations sent by a user, organized by status, with ability to track status changes
- **FR-010**: System MUST prevent duplicate invitations (cannot send multiple pending invitations to the same user)
- **FR-011**: System MUST prevent self-invitations (user cannot send invitation to themselves)
- **FR-012**: System MUST track invitation timestamps (sent date, response date if applicable) for display and sorting
- **FR-013**: Backend MUST expose invitation data through APIs that specify sender and receiver relationships for frontend consumption
- **FR-014**: System MUST handle rejection gracefully - recipient can send a new invitation after rejecting, or sender can resend after recipient rejects

---

### Key Entities *(include if feature involves data)*

- **Invitation**: Core entity representing a request for conversation
  - `id`: Unique identifier
  - `sender_id`: Foreign key to sending user
  - `receiver_id`: Foreign key to receiving user
  - `status`: Enum (Pending, Accepted, Rejected, Canceled)
  - `created_at`: Timestamp when invitation was sent
  - `responded_at`: Timestamp when recipient accepted or rejected (null if pending)
  - `canceled_at`: Timestamp when sender canceled (null if not canceled)

- **Chat**: Entity representing an active conversation between users
  - `id`: Unique identifier
  - `participant_ids`: List of user IDs in the chat
  - `created_at`: Timestamp when chat was created (typically when invitation accepted)
  - `initiated_by_invitation_id`: Foreign key linking to the invitation that created this chat

- **User**: Existing entity, relevant attributes
  - `id`: Unique identifier
  - `blocked_users`: List of user IDs this user has blocked (for blocking validation)

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully send an invitation and see the recipient in their sent invitations list within 2 seconds
- **SC-002**: Invitation recipients receive notifications and can see pending invitations within 5 seconds of invitation being sent
- **SC-003**: Accepting or rejecting an invitation completes within 2 seconds and creates/maintains appropriate chat state
- **SC-004**: System prevents duplicate invitations to the same user - second attempt returns clear error message or UI feedback
- **SC-005**: System correctly handles 100+ concurrent invitations without data loss or status inconsistencies
- **SC-006**: 95% of invitation state changes propagate to both sender and recipient within 5 seconds
- **SC-007**: Canceled invitations are removed from recipient's inbox within 3 seconds on next refresh or real-time update
- **SC-008**: Users can access their invitation history (sent and received) with full status visibility

---

## Assumptions

1. **User Authentication**: Users are already authenticated before accessing invitation features
2. **User Search/Discovery**: A mechanism already exists for users to find and view other user profiles
3. **Chat Creation**: The system already has a chat creation mechanism; invitations trigger this via backend API
4. **Notifications**: A notification system exists to alert users of new invitations and status changes
5. **Blocking System**: A blocking/restriction system exists that the invitation system should respect
6. **Frontend State Management**: Frontend has state management (Redux, Riverpod, etc.) to store and update invitation data
7. **Real-time Updates**: System assumes either polling or WebSocket-based real-time updates for status changes
8. **Timestamps**: All timestamps use server time to ensure consistency across distributed clients
9. **Status Transitions**: Once an invitation is accepted or rejected, it cannot transition back to pending (final states)
10. **Concurrency**: When conflicts occur (e.g., mutual invitations), system prioritizes the invitation created first

---

## Data Flow Diagram

```
User A (Sender)                    Backend                    User B (Receiver)
    |                                |                              |
    |-- Send Invitation ---------->  | (Create Invitation)          |
    |                                | (status: Pending)            |
    |                                |--- Notify User B ----------->|
    |                                |                    (See Pending)
    |                                |                              |
    |                                | <--- Accept/Reject/Cancel    |
    |                                | (Update Invitation)          |
    | <--- Status Update -----       |                              |
    |    (Notification)              |--- Notify/Update ---------> |
    |                                |                              |
    | (For Sent List)                | (For Received List)          |
    |<--- Fetch Invitations -------->| (Query by sender_id)        |
    |                                | (Query by receiver_id) ----->|
```
