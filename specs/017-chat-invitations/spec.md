# Feature Specification: Chat Invitations

**Feature Branch**: `017-chat-invitations`  
**Created**: 2026-03-14  
**Status**: Ready for Implementation Planning ✅
**Clarifications Approved**: 2026-03-14

## Overview

Users need a way to initiate conversations with other users through a formal invitation system. This feature enables users to send chat invitations to others, manage pending invitations, and create new conversations through acceptance.

## User Scenarios & Testing

### User Story 1 - Send Chat Invitation (Priority: P1)

A user discovers another user they want to chat with and sends them a formal invitation. This is the entry point for creating new connections.

**Why this priority**: Core feature - without the ability to send invites, the entire system cannot function. This is the primary mechanism for users to initiate conversations.

**Independent Test**: Fully testable by: User navigates to a discovery/search interface, finds another user, sends an invite, and verifies the invite appears in recipient's pending list.

**Acceptance Scenarios**:

1. **Given** user is viewing a list of available users (or search results), **When** they select another user and tap "Send Invite", **Then** the system creates an invitation record and displays a success confirmation.

2. **Given** user has sent an invitation, **When** they view their sent invitations, **Then** they see the recipient's name and the invite status marked as "Pending".

3. **Given** user tries to send an invitation to someone already in their contacts/chats, **When** they attempt to send, **Then** the system prevents the action and shows a message explaining the user is already a contact.

---

### User Story 2 - View Pending Invitations (Priority: P1)

A user can see all invitations they've received that are awaiting their response. This gives visibility into pending social connections.

**Why this priority**: Critical companion to P1 - users cannot act on invites if they cannot see them. Essential for completing the invitation workflow.

**Independent Test**: Fully testable by: User views their invitations interface and can see a list of pending invites with sender information and action buttons.

**Acceptance Scenarios**:

1. **Given** user has received one or more chat invitations, **When** they navigate to the Invitations section, **Then** they see a list of pending invites with sender name/avatar and timestamp.

2. **Given** the invitations list is empty, **When** user navigates to Invitations, **Then** they see a friendly empty state message (e.g., "You have no pending invites").

3. **Given** user has many pending invites, **When** they view the list, **Then** the list clearly distinguishes between unread and read invitations.

---

### User Story 3 - Accept Chat Invitation (Priority: P1)

A user reviews a pending invitation and accepts it, which creates a new chat session with the inviter and opens their conversation.

**Why this priority**: Critical - this completes the invitation flow and creates the actual chat. Without this, invites are meaningless.

**Independent Test**: Fully testable by: User receives an invite, navigates to pending invitations, taps "Accept", and verifies that a new chat appears in their chat list and is opened.

**Acceptance Scenarios**:

1. **Given** user is viewing a pending invitation, **When** they tap the "Accept" button, **Then** the system creates a chat between the two users and displays the chat conversation view.

2. **Given** user accepts an invitation, **When** they look at their chat list, **Then** the new chat appears with the inviting user's name and a recent message timestamp.

3. **Given** user accepts an invitation, **When** other users in the system check their contact lists or chat history, **Then** they see the new connection/chat established.

---

### User Story 4 - Decline Chat Invitation (Priority: P2)

A user can reject an invitation they don't want to accept, which removes it from their pending list.

**Why this priority**: Important for UX - users need to manage their invitations. However, the system still functions without this if invites eventually expire. This is a polish feature that improves usability.

**Independent Test**: Fully testable by: User views pending invitation, taps "Decline", and verifies it's removed from the list.

**Acceptance Scenarios**:

1. **Given** user is viewing a pending invitation they don't want to accept, **When** they tap "Decline", **Then** the invitation is immediately removed from their pending list.

2. **Given** user has declined an invitation, **When** the inviter checks their sent invitations, **Then** they see the invitation status is marked as "Declined".

3. **Given** user has declined an invitation from a person, **When** that person tries to send another invitation, **Then** the system allows it (declining doesn't permanently block).

---

### Edge Cases

- **Simultaneous mutual invites**: If User A sends invite to User B while User B sends invite to User A, both invites should exist independently. When one is accepted, the other should be automatically removed or marked as "Chat Already Exists".

- **Invite after chat exists**: If User A and User B are already chatting, attempts to send a new invite between them should be blocked with a message "Already in contact".

- **Self-invites**: Users should not be able to send an invitation to themselves.

- **Invite acceptance during network issues**: If the system loses connectivity during acceptance, the operation should either succeed fully or fail fully.

- **Deleted users**: If an inviter deletes their account after sending an invite, the pending invite should handle this gracefully.

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST validate that the invitee is not the same user as the inviter (no self-invites).

- **FR-002**: System MUST prevent sending invitations to users who are already chat contacts.

- **FR-003**: System MUST create an `Invite` record with sender_id, recipient_id, status, created_at, and updated_at fields.

- **FR-004**: System MUST allow users to view their pending invitations with sender information sorted by most recent first.

- **FR-005**: System MUST create a new `Chat` between sender and recipient when an invitation is accepted.

- **FR-006**: System MUST add both users to the chat members when invitation is accepted.

- **FR-007**: System MUST update the invitation status to "accepted" when accepted, or "declined" when declined.

- **FR-008**: System MUST remove the invitation from the pending list for the recipient after acceptance or decline.

- **FR-009**: System MUST provide a search or user discovery interface where users can find other users to invite.

- **FR-010**: System MUST validate that users attempting to send invites are authenticated and authorized.

- **FR-011**: System MUST allow users to decline an invitation without creating a lasting block.

- **FR-012**: System MUST notify the recipient of a new invitation via in-app badge on the "Invitations" tab AND push notification (if user has enabled push notifications).

- **FR-013**: Pending invitations MUST persist indefinitely until explicitly accepted, declined, or automatically removed when a chat is created between the two users.

- **FR-014**: System MUST display an "Invitations" tab in the main app navigation (bar) with a badge showing the count of unread/pending invitations.

- **FR-015**: The Invitations tab MUST display two sections: "Pending Invitations" (received) and "Sent Invitations" (awaiting recipient action).

- **FR-016**: Users MUST be able to initiate new invitations from within the Invitations tab (e.g., via a "Send Invite" button that navigates to user discovery).

### Key Entities

- **ChatInvite**: Represents an invitation between two users
  - `id`: Unique identifier
  - `sender_id`: User who sent the invite (FK to Users)
  - `recipient_id`: User who received the invite (FK to Users)
  - `status`: Enum ("pending", "accepted", "declined")
  - `created_at`: Timestamp when sent
  - `updated_at`: Timestamp when last updated

- **Chat**: Extended to track invitations
  - Relationship to ChatInvite if tracking invite origin

- **User**: Existing entity - no changes for this feature

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can send an invitation to another user within 60 seconds of discovering them.

- **SC-002**: Pending invitations appear in recipient's inbox within 3 seconds of being sent.

- **SC-003**: Users can accept an invitation and see the new chat in chat list within 2 seconds.

- **SC-004**: System prevents duplicate invitations - users cannot send multiple new invites to same person while one is pending.

- **SC-005**: Declining an invitation removes it from pending list immediately.

- **SC-006**: Users cannot send an invite to someone they're already chatting with (validation prevents).

- **SC-007**: System handles 100+ pending invitations for a single user without performance degradation.

- **SC-008**: 95% of users successfully complete invite flow (send → accept) on first attempt.

---

## Assumptions

- Users and authentication already exist in the system.

- A Chat/Direct Message entity already exists for conversations.

- User discovery/search interface exists or is being built separately.

- No special permissions needed for invitations.

- Accepted invitations create 1-to-1 chats (not group chats).

- Network operations are idempotent.

---

## Clarifications - RESOLVED ✅

**Date Clarified**: 2026-03-14

### Q1: Notification Method → **RESOLVED: In-app badge + push notification**
Recipients will be notified via:
- In-app badge/notification bubble on "Invitations" tab
- Push notification to their device (if push notifications are enabled)
- This ensures users discover new invites promptly without needing email

**Implementation Impact**: Requires integration with push notification service; in-app UI should show unread badge count on Invitations tab.

---

### Q2: Invite Expiration → **RESOLVED: Never expire**
Pending invitations will:
- Remain in the system indefinitely until accepted, declined, or chat is created
- Not automatically expire after a time period
- Persist across user sessions and app updates

**Implementation Impact**: No scheduled expiration cleanup job needed; simplifies data model; users responsible for managing their own invitations.

---

### Q3: UI Navigation → **RESOLVED: Dedicated "Invitations" tab in main navigation**
The feature will be accessed via:
- A dedicated "Invitations" tab in the main app navigation (alongside Chats, Contacts, etc.)
- Tab shows badge with count of unread/pending invitations
- Tab displays both received invitations (to accept/decline) and sent invitations (pending status view)
- Users can send new invitations from within this screen

**Implementation Impact**: Requires adding new tab to main navigation; new screen layout for invitations list; tab bar icon and styling needed.
