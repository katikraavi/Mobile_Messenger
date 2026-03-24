specify: Implement Chat Invitations

Goal
Users can invite others to chat.

Features
- send invite
- accept invite
- decline invite
- pending invites list

Rules
- cannot invite existing chat contact

Acceptance Criteria
- invite sent
- invite accepted creates chat
- invite declined removes invite

What to test
- User1 sends invite to User2
- User2 sees invite in pending list
- User2 accepts invite → chat created
- User2 declines invite → invite removed
- Try inviting same user again after chat exists
