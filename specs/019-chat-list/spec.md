# Feature Specification: Chat List

**Feature Branch**: `019-chat-list`  
**Created**: 2026-03-15  
**Status**: Draft  
**Input**: Display user's chats with sorting, archive, and messaging capabilities

## User Scenarios & Testing

### User Story 1 - View Chat List Sorted by Recent Activity (Priority: P1)

As a user who has accepted invitations from friends, I want to see all my active conversations in a single list so I can quickly find and start messaging with friends.

The chat list displays all chats sorted by most recent message (received or sent), showing the friend's name, last message snippet, and timestamp. The most active conversation appears at the top, making it easy to continue recent conversations.

**Why this priority**: This is the core functionality - without a way to view and access chats, the entire messaging system has no value. Users must be able to immediately see their conversations upon opening the app.

**Independent Test**: Can be fully tested by creating 2-3 chats with different users, placing messages at different times, and verifying newest chat appears first. This alone delivers the MVP: "I can see my conversations organized by recency."

**Acceptance Scenarios**:

1. **Given** a user has 3 accepted invitations with different friends, **When** they open the app and navigate to the chat list, **Then** all 3 chats are displayed
2. **Given** user has chats with Friends A (last message 1 hour ago), B (30 minutes ago), C (5 minutes ago), **When** viewing the chat list, **Then** chats appear in order: C, B, A (newest first)
3. **Given** a chat list is displayed, **When** a user taps on any chat, **Then** the chat detail screen opens showing the conversation history with that specific friend
4. **Given** multiple chats exist, **When** a new message arrives in Chat A, **Then** Chat A immediately moves to the top of the list and timestamp updates
5. **Given** no chats exist yet, **When** user views the chat list, **Then** empty state message appears: "No chats yet. Accept an invitation to start messaging!"

---

### User Story 2 - Send and Receive Messages (Priority: P1)

As a user, I want to send text messages to a friend in a chat and see their responses so I can have a real-time conversation.

In the chat detail screen, users can type messages and send them. Sent messages appear immediately with a timestamp. Received messages appear in the chat with sender information and timestamp. Messages are persisted so the conversation history is maintained.

**Why this priority**: Without message functionality, the chat list is just decoration. Sending/receiving messages is the core value proposition. This must work before anything else.

**Independent Test**: Can be fully tested with 2 users, User A sends a message, User B receives it and replies, User A sees the reply. This delivers: "I can actually message my friends."

**Acceptance Scenarios**:

1. **Given** user Bob opens a chat with friend Alice, **When** Bob types a message and taps "Send", **Then** the message appears in Bob's chat immediately with timestamp
2. **Given** Alice is in her chat with Bob, **When** Bob sends a message, **Then** Alice sees Bob's message appear in her chat with sender name and timestamp
3. **Given** a message is sent, **When** the conversation history is viewed, **Then** the message is displayed with date/time
4. **Given** both users are in the chat, **When** a user sends a message, **Then** it appears in real-time for both users (within 2 seconds)
5. **Given** a message has been sent, **When** user refreshes or closes/reopens the app, **Then** the message history is preserved and visible

---

### User Story 3 - Archive and Unarchive Chats (Priority: P2)

As a user with many active chats, I want to archive chats I'm not actively using so I can focus on important conversations while keeping the option to restore them later.

Users can long-press or swipe on a chat to reveal an "Archive" option. Archived chats are removed from the main list but remain accessible in an "Archived" section. Users can tap "Unarchive" to restore an archived chat to the main list.

**Why this priority**: Important for app usability, but not required for MVP. Users need message functionality first. Archiving enhances organization for power users.

**Independent Test**: Can be tested independently by archiving a chat, verifying it disappears from main list, then unarchiving and verifying it returns. Doesn't depend on messaging functionality.

**Acceptance Scenarios**:

1. **Given** user has 3 chats in the main chat list, **When** user long-presses a chat, **Then** an "Archive" option/button appears
2. **Given** "Archive" is tapped, **When** the chat list refreshes, **Then** the archived chat no longer appears in the main list
3. **Given** a chat is archived, **When** user taps the "Archived" section/tab, **Then** archived chats are displayed separately
4. **Given** a chat is archived, **When** user taps "Unarchive", **Then** the chat is restored to the main chat list
5. **Given** a chat is archived, **When** a new message arrives for that chat, **Then** the chat remains archived (does not auto-restore) but shows a notification

---

### Edge Cases

- What happens if a message fails to send? System should show an error indicator and allow retry
- How does the system handle very long message text (100+ characters)? Text should wrap appropriately
- What happens if a user receives a message while archived chats are being viewed? Notification should still alert the user
- How does the system handle a user receiving messages from someone they haven't accepted an invitation from? Should not allow messaging until invitation is accepted
- What happens if the chat list has 100+ chats? Should implement pagination or infinite scroll for performance
- What if a user is typing but loses network connection? Message should queue and retry when connection restored

## Requirements

### Functional Requirements

- **FR-001**: System MUST display all chats for the logged-in user in a single list
- **FR-002**: System MUST sort chats by timestamp of the last message (most recent first)
- **FR-003**: System MUST immediately move a chat to the top when a new message arrives in that chat
- **FR-004**: System MUST display for each chat: friend's name, last message preview (first 50 chars), and relative timestamp (e.g., "2m ago", "1h ago")
- **FR-005**: Users MUST be able to tap a chat to open the conversation detail screen
- **FR-006**: Users MUST be able to send text messages within a chat
- **FR-007**: Users MUST be able to see sent and received messages in chronological order
- **FR-008**: System MUST persist the message history for each chat
- **FR-009**: Users MUST be able to archive a chat so it no longer appears in the main list
- **FR-010**: Users MUST be able to view an "Archived" section containing archived chats
- **FR-011**: Users MUST be able to unarchive a chat to restore it to the main list
- **FR-012**: System MUST show an empty state when no chats exist with message: "No chats yet. Accept an invitation to start messaging!"
- **FR-013**: System MUST update the chat list and message timestamps in real-time as time passes
- **FR-014**: System MUST prevent messaging with users from whom no invitation has been accepted
- **FR-015**: System MUST handle message sending errors gracefully with error indication and retry option

### Key Entities

- **Chat**: Represents a conversation between the current user and another user. Contains: chat_id, user_id, other_user_id, last_message_time, archived (boolean), created_at, updated_at
- **Message**: Represents a single message in a chat. Contains: message_id, chat_id, sender_id, text_content, sent_at, read_at (optional)
- **User**: Represents a participant in a chat. Contains: user_id, username, email, avatar_url

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can access their chat list and view all active conversations in under 500ms after opening the app
- **SC-002**: A newly sent message appears in both sender's and receiver's chat within 2 seconds
- **SC-003**: Chat list is properly sorted by message timestamp with 100% accuracy (100+ chat test cases pass)
- **SC-004**: Archive/unarchive functionality works correctly with 100% success rate across all test scenarios
- **SC-005**: Message history is preserved across app restarts (0 data loss verified through testing)
- **SC-006**: System handles 50+ messages in a single chat without performance degradation
- **SC-007**: Empty state message displays correctly when no chats exist (P1 requirement)
- **SC-008**: Users report improved ability to manage conversations (measured by reduced chat search requests in future versions)
- **SC-009**: Chat notification system alerts users to new messages within 5 seconds of receipt
- **SC-010**: 95% of users can successfully navigate from chat list to sending their first message without instruction

## Assumptions

- **Technology**: Uses same backend as invitations system; new Chat and Message database tables created with proper indexes
- **Authentication**: Users are already authenticated (invitation system prerequisite)
- **User Relationships**: Only users with accepted invitations can message each other (pre-established by invitations feature)
- **Data Model**: Messages are stored in database; chat list is derived by querying messages by user_id and sorting by timestamp
- **Real-time**: Messages sync via same mechanisms as rest of app (polling or WebSocket - existing infrastructure reused)
- **Default Behavior**: Archive status persists across app restarts; archived chats don't auto-unarchive on new messages (by design)
- **Performance**: Chat list limited to ~50 visible items with pagination/infinite scroll for larger lists
- **Edge Case Handling**: Network errors show user-friendly messages; failed messages remain in UI with retry button
- **Platform**: Testing occurs on Android emulator; iOS testing deferred if different behavior expected

## Dependencies

- Requires: Invitation System (users must accept invitations before messaging)
- Requires: User Authentication System (must know logged-in user's ID)
- Requires: Established database schema for chats and messages
- Requires: Backend API endpoints for: GET /chats, GET /chats/{id}/messages, POST /messages, PUT /chats/{id}/archive, PUT /chats/{id}/unarchive

## Not Included (Out of Scope)

- Group chats (1:1 messaging only)
- Message editing or deletion
- Message reactions or emojis
- Message search functionality
- Call/video integration
- Message pinning
- Message forwarding
- Typing indicators
- Read receipts
- End-to-end encryption
