# Feature Specification: Chat List Last Message Preview

**Feature Branch**: `021-chat-list-last-message`  
**Created**: March 19, 2026  
**Status**: Draft  
**Input**: User description: "Display last message preview and timestamp in chat list, sort chats by most recent message, update order when new messages arrive."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See Last Message Preview (Priority: P1)

As a user, when I view the chat list, I see a preview of the last message (text or media indicator) and the time it was sent under each chat participant's name.

**Why this priority**: This gives immediate context for each chat and is the main value of the chat list.

**Independent Test**: Can be fully tested by sending messages and verifying the preview and timestamp update in the chat list.

**Acceptance Scenarios**:

1. **Given** a chat with no messages, **When** viewing the chat list, **Then** show "No messages yet" under the participant name.
2. **Given** a chat with messages, **When** viewing the chat list, **Then** show the beginning of the last message and the time sent under the participant name.

---

### User Story 2 - Chats Ordered by Last Message (Priority: P2)

As a user, when I view the chat list, chats are ordered by the time of the last message sent or received, with the most recent chat at the top.

**Why this priority**: Ensures the most active conversations are easily accessible.

**Independent Test**: Can be tested by sending messages in different chats and verifying the order updates.

**Acceptance Scenarios**:

1. **Given** multiple chats, **When** a new message is sent or received, **Then** the chat moves to the top of the list.

---

### User Story 3 - Real-Time Update of Chat List (Priority: P3)

As a user, when a new message arrives in any chat, the chat list updates immediately to show the new preview and moves the chat to the top.

**Why this priority**: Keeps the chat list current and responsive.

**Independent Test**: Can be tested by sending/receiving messages and observing immediate update in the chat list.

**Acceptance Scenarios**:

1. **Given** the chat list is open, **When** a new message arrives, **Then** the chat preview and order update instantly.

---


### Edge Cases

- What happens when a chat has no messages? → Show "No messages yet".
- How does system handle media messages? → Show a media indicator formatted as "[Photo]", "[Audio]", "[Video]", etc. Preview must not leak sensitive content and must be encrypted.
- What if messages arrive out of order? → Always use the latest message timestamp for sorting. Add test for this scenario.
- What if a message fails to send? → Show a sending indicator, do not update order until confirmed.
- What happens if user uploads a new profile picture? → Show the new picture immediately in chat list and chat window. If user has not changed picture, show default profile picture.

### Security & Encryption

- All message previews and media indicators MUST be encrypted before transmission or storage. No plaintext previews allowed.

### User Picture Logic

- Chat list and chat window MUST display the user's current profile picture. If a new picture is uploaded, it must be shown immediately. If no picture is set, show the default profile picture.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display the last message preview and timestamp under each chat participant's name in the chat list.
- **FR-002**: System MUST show "No messages yet" for chats with no messages.
- **FR-003**: System MUST sort chats by the timestamp of the last message, most recent first.
- **FR-004**: System MUST update the chat list order and preview immediately when a new message is sent or received.
- **FR-005**: System MUST handle media messages with a clear indicator in the preview.
- **FR-006**: System MUST update the chat list in real-time when messages arrive via WebSocket or push.

### Key Entities

- **Chat**: Represents a conversation between two users. Attributes: id, participant1Id, participant2Id, createdAt, updatedAt, lastMessage, lastMessageTimestamp.
- **Message**: Represents a message in a chat. Attributes: id, chatId, senderId, content, type (text, media), timestamp, status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of chats in the list display the correct last message preview and timestamp.
- **SC-002**: Chat list order always reflects the most recent message activity.
- **SC-003**: Chat list updates within 1 second of a new message arriving or being sent.
- **SC-004**: Users report improved satisfaction with chat list clarity and responsiveness.

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]  
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Key Entities *(include if feature involves data)*

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]
