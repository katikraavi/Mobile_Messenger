# Feature Specification: Messaging with Status Indicators and Typing Notifications

**Feature Branch**: `020-message-status-typing`  
**Created**: 2026-03-16  
**Status**: Draft  
**Input**: User description: "user should actually be able to send and recieve messages, so there will be typing indicator, that shows if the other user is typing, messages should have status sent, delivered read. user should be able to edit or delete the message and it should be clear in frontend"

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Send Message with Instant Visual Feedback (Priority: P1)

Users need to send messages in a chat and immediately see that the message was sent, with clear indication of its delivery status.

**Why this priority**: Sending messages is the core functionality of any messaging system. Without this, the app is non-functional as a messenger.

**Independent Test**: Can be fully tested by opening a chat, typing a message, clicking send, and verifying the message appears with a "sent" indicator. Delivers core messaging value.

**Acceptance Scenarios**:

1. **Given** user is in an active chat, **When** user types text and clicks send, **Then** message appears in chat history with "sent" status indicator (checkmark icon)
2. **Given** message is sent, **When** backend processes it, **Then** status changes to "delivered" indicator (double checkmark)
3. **Given** message is delivered, **When** recipient reads it, **Then** status changes to "read" indicator (blue double checkmark or similar)
4. **Given** recipient is offline, **When** user sends message, **Then** message shows "sent" status and eventually "delivered" when recipient comes online
5. **Given** network is unavailable, **When** user sends message, **Then** message shows "pending" status with retry option

---

### User Story 2 - Receive Messages with Read Receipts (Priority: P1)

Users need to receive messages from other users and have those messages marked as read when they view them.

**Why this priority**: This is equally core to sending - messaging requires bidirectional communication. Read receipts provide conversation awareness.

**Independent Test**: Can be tested by another user sending a message and verifying it appears immediately on recipient's device with proper status updates. Delivers core messaging value.

**Acceptance Scenarios**:

1. **Given** another user sends a message to current user, **When** message arrives at receiver, **Then** message appears in chat with "delivered" status
2. **Given** message is visible on recipient's screen, **When** user opens chat or message is in viewport, **Then** system marks message as "read"
3. **Given** message is marked as read, **When** sender views chat, **Then** sender sees blue/highlighted read indicator on that message
4. **Given** user receives message while app is closed, **When** user opens app/chat, **Then** message appears with all status indicators
5. **Given** multiple messages from same sender, **When** user opens chat, **Then** all unread messages marked as read simultaneously

---

### User Story 3 - Typing Indicator Shows Active Typing (Priority: P1)

Users need to see when the other person is actively typing, providing real-time conversation awareness.

**Why this priority**: Typing indicators are standard UX in modern messaging and prevent confusion about whether conversation is active. This enhances user experience significantly.

**Independent Test**: Can be tested by user A typing while user B watches, seeing typing indicator appear/disappear. Delivers better UX and conversation flow awareness.

**Acceptance Scenarios**:

1. **Given** user starts typing in message input field, **When** user types keystrokes, **Then** system sends typing indicator to other user
2. **Given** typing indicator sent, **When** other user views chat, **Then** they see "[Name] is typing..." indicator below message history
3. **Given** user stops typing (no keystrokes for 3 seconds), **When** timeout occurs, **Then** typing indicator disappears automatically
4. **Given** user completes typing, **When** user sends message, **Then** typing indicator disappears immediately
5. **Given** user is typing, **When** message from other person arrives, **Then** typing indicator remains visible and message appears above
6. **Given** typing indicator active, **When** both users are typing, **Then** show individual indicator for each user

---

### User Story 4 - Edit Message with Clear Indication (Priority: P2)

Users need to edit previously sent messages with clear indication that a message has been edited.

**Why this priority**: Editing is a quality-of-life feature that prevents needing to delete and resend. Important for user satisfaction but not blocking core messaging.

**Independent Test**: Can be tested by editing a message and verifying edit appears in message history and is visible to both users. Delivers message control value.

**Acceptance Scenarios**:

1. **Given** user sends a message, **When** user long-presses or right-clicks message, **Then** edit option appears in menu
2. **Given** edit option selected, **When** user modifies text and confirms, **Then** message updates in chat with "(edited)" indicator
3. **Given** message is edited, **When** other user views chat, **Then** they see same message with "(edited)" indicator
4. **Given** user edits message multiple times, **When** checking message details, **Then** edit history shows "last edited [time]"
5. **Given** message is edited, **When** timestamp is shown, **Then** shows "sent at [time], edited at [time]"

---

### User Story 5 - Delete Message with Confirmation (Priority: P2)

Users need to delete messages they've sent with confirmation and proper indication to both parties.

**Why this priority**: Deletion is important for privacy control but secondary to core messaging functionality. Some users need this feature for accidental sends or private reasons.

**Independent Test**: Can be tested by deleting a message and verifying it disappears with notification shown to other user. Delivers message control and privacy.

**Acceptance Scenarios**:

1. **Given** user sends a message, **When** user long-presses or right-clicks message, **Then** delete option appears in menu
2. **Given** delete selected, **When** user confirms deletion, **Then** message is removed from chat history and replaced with "[message deleted]" or similar placeholder
3. **Given** message is deleted, **When** other user views chat, **Then** they see placeholder indicating message was deleted (not just silently removed)
4. **Given** user deletes message, **When** deletion occurs, **Then** system logs deletion event for audit trail
5. **Given** message is deleted by sender, **When** recipient had not read it, **Then** notification is not shown and message simply disappears on sync

---

### User Story 6 - Rich Status Display in Message List (Priority: P2)

Users need to see comprehensive message status information without hovering or opening details.

**Why this priority**: Good UX for understanding message delivery at a glance. Enhances confidence in message delivery. Secondary to core messaging but important for usability.

**Independent Test**: Can be tested by sending messages and verifying status icons appear and update correctly in the message list. Provides delivery confidence.

**Acceptance Scenarios**:

1. **Given** message in chat history, **When** user views message, **Then** status indicator is visible (single checkmark, double checkmark, blue double checkmark)
2. **Given** status indicator visible, **When** user hovers over or taps indicator, **Then** tooltip shows full status text ("Sent", "Delivered", "Read")
3. **Given** message being sent, **When** network request pending, **Then** show loading spinner or animated status instead of static checkmark
4. **Given** message fails to send, **When** error occurs, **Then** show red error icon and allow user to retry

---

### Edge Cases

- What happens when user tries to edit/delete a message that was already deleted by the other user?
- How does system handle when message is marked read but then user navigates away and back to chat?
- What happens if user sends message while offline - should failed messages be queued or require manual retry?
- How does system handle if typing indicator timeout doesn't trigger (network lag) - does duplicate indicator show?
- What if user edits message to empty string - should that be treated as deletion?
- How does system handle when two users edit the same message simultaneously?
- What happens if recipient has read receipts disabled - do other users see "delivered" but never "read"?
- Should delete be hard delete (unrecoverable) or soft delete (recoverable by admins)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to type text in a message input field while viewing a chat
- **FR-002**: System MUST send the message to the recipient when user clicks send button
- **FR-003**: System MUST display sent message in sender's chat history with "sent" status indicator immediately
- **FR-004**: System MUST update message status from "sent" to "delivered" when message reaches backend
- **FR-005**: System MUST update message status to "read" when recipient opens the message or message enters recipient's viewport
- **FR-006**: System MUST send typing indicator to other participant when user types (after 100ms of inactivity triggers start, after 3s of inactivity triggers stop)
- **FR-007**: System MUST display typing indicator on recipient's device as "[Recipient Name] is typing..." below message history
- **FR-008**: System MUST remove typing indicator when sender stops typing or sends message
- **FR-009**: System MUST allow user to edit previously sent messages via context menu (long-press or right-click)
- **FR-010**: System MUST display "(edited)" indicator on edited messages in chat history
- **FR-011**: System MUST show "last edited at [timestamp]" when user views edited message details or hovers over
- **FR-012**: System MUST allow user to delete messages via context menu
- **FR-013**: System MUST show "[message deleted]" or similar placeholder when message is deleted instead of removing without trace
- **FR-014**: System MUST notify recipient of deletion in real-time (placeholder appears instead of message)
- **FR-015**: System MUST persist message status information (sent, delivered, read) in database
- **FR-016**: System MUST allow status indicators to be clicked/tapped to show detailed status information (timestamps)
- **FR-017**: System MUST support concurrent typing from multiple users (show indicator for each participant)
- **FR-018**: System MUST validate message content is not empty before allowing send
- **FR-019**: System MUST maintain message order by creation timestamp
- **FR-020**: System MUST handle network failures gracefully by showing pending status with retry option

### Key Entities *(include if feature involves data)*

- **Message**: Individual message unit with content, sender, recipient, timestamp, edit history, deletion status, read status
  - Attributes: id, chatId, senderId, recipientId, content, status (pending/sent/delivered/read), createdAt, editedAt, deletedAt, isDeleted
  - Relationships: belongs to Chat, sent by User, received by User
  
- **MessageStatus**: Tracking of message delivery and read state per recipient
  - Attributes: messageId, recipientId, status (sent/delivered/read), deliveredAt, readAt
  - Relationships: unique per message-recipient pair

- **TypingIndicator**: Real-time indication of active typing
  - Attributes: chatId, userId, typingStartedAt, typingStoppedAt
  - Relationships: ephemeral, not persisted (real-time only)

- **MessageEdit**: Audit trail of message modifications
  - Attributes: messageId, editNumber, previousContent, newContent, editedAt, editedBy
  - Relationships: belongs to Message

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can send a message and see it appear in chat history with status indicator within 500ms
- **SC-002**: Message status changes from "sent" to "delivered" within 2 seconds of sending
- **SC-003**: Message status changes from "delivered" to "read" within 500ms of message becoming visible
- **SC-004**: Typing indicator appears on recipient device within 1 second of sender starting to type
- **SC-005**: Typing indicator disappears within 3.5 seconds of sender stopping typing (3s timeout + 500ms network latency)
- **SC-006**: Edit operation completes and is visible to both users within 1 second
- **SC-007**: Delete operation completes and shows placeholder to both users within 1 second
- **SC-008**: 95% of messages are successfully delivered without user intervention or retry
- **SC-009**: System maintains message history with all status and edit information intact during session
- **SC-010**: Duplicate typing indicators do not appear (maximum one per user in chat)

## Assumptions

- Users have established chat relationship before messaging (invitations already accepted, chat created)
- Backend has real-time communication mechanism (WebSockets, Server-Sent Events, or polling) for status updates and typing indicators
- Message editing should only be available to the sender, not recipients
- Message deletion should only be available to the sender
- Read receipts are enabled by default (but system allows disabling per user if configured)
- Typing indicators are real-time signals, not persisted historical data
- User must be authenticated with valid JWT token to send/receive messages
- Chat must exist and user must be participant in chat to access it

## Out of Scope

- Group messaging with 3+ participants (focus on 1-to-1 for MVP)
- Message replies/threading
- Rich media (images, files) - text only for this spec
- Message reactions/emojis
- Forwarding messages
- Pinning important messages
- Search/filter message history
- End-to-end encryption
