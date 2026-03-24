# Quick Start: Chat List Feature Testing

**Purpose**: Local testing guide for Chat List implementation.  
**Prerequisites**: Flask application running, Android emulator configured, database initialized.  
**Estimated Time**: 15 minutes for full 2-user flow  

---

## Setup: Backend Support

### 1. Add Chat Endpoints to Shelf Backend

Backend changes needed (to be implemented in Phase 1):

**File**: `backend/lib/src/handlers/chat_handlers.dart` (NEW)

```dart
import 'package:shelf/shelf.dart';
import '../services/chat_service.dart';

Handler chatHandlers(ChatService chatService) {
  var router = Router();

  // GET /api/chats - List all active chats
  router.get('/api/chats', (Request request) async {
    final userId = request.context['user_id'] as String?;
    if (userId == null) return Response(401);
    
    final chats = await chatService.getActiveChats(userId);
    return Response.ok(jsonEncode(chats),
        headers: {'content-type': 'application/json'});
  });

  // GET /api/chats/{chatId}/messages - Message history
  router.get('/api/chats/<chatId>/messages', (Request request, String chatId) async {
    final userId = request.context['user_id'] as String?;
    if (userId == null) return Response(401);
    
    final messages = await chatService.getMessages(chatId, userId, limit: 20);
    return Response.ok(jsonEncode(messages),
        headers: {'content-type': 'application/json'});
  });

  // POST /api/chats/{chatId}/messages - Send message
  router.post('/api/chats/<chatId>/messages', (Request request, String chatId) async {
    final userId = request.context['user_id'] as String?;
    if (userId == null) return Response(401);
    
    final body = jsonDecode(await request.readAsString());
    final message = await chatService.sendMessage(
      chatId: chatId,
      senderId: userId,
      encryptedContent: body['encrypted_content'],
    );
    
    return Response.ok(jsonEncode(message),
        headers: {'content-type': 'application/json'});
  });

  return router;
}
```

### 2. Initialize Database Schema

Run migration to create `chats` and `messages` tables:

```sql
-- backend/migrations/003_create_chats_messages.sql

CREATE TABLE chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participant_2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_participant_1_archived BOOLEAN NOT NULL DEFAULT FALSE,
  is_participant_2_archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(participant_1_id, participant_2_id),
  CHECK(participant_1_id <> participant_2_id)
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id),
  encrypted_content TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chats_participant_1_active 
ON chats(participant_1_id, updated_at DESC) 
WHERE is_participant_1_archived = FALSE;

CREATE INDEX idx_messages_chat_created 
ON messages(chat_id, created_at DESC);
```

Run migration:
```bash
cd backend
psql -U messenger_user -d messenger_db -f migrations/003_create_chats_messages.sql
```

---

## Setup: Frontend Support

### 1. Add Chat Feature Module

Create directory structure:
```bash
mkdir -p frontend/lib/features/chats/{screens,providers,models,services,widgets}
mkdir -p frontend/test/features/chats/{providers,services,screens}
```

### 2. Assume Models Already Exist

For this quick start, assume:
- `chat_model.dart` ✓ Created
- `message_model.dart` ✓ Created
- `chat_api_service.dart` ✓ Basic structure

---

## Test Scenario: 2-User Chat Flow

### Step 1: Start Backend

```bash
cd backend
docker-compose up --build
```

Verify backend is running:
```bash
curl -X GET http://localhost:8081/health
# Expected: 200 OK
```

### Step 2: Start Android Emulator

```bash
flutter run -d emulator-5554
```

The emulator should connect to `172.31.195.26:8081` (WSL2 host IP).

### Step 3: Run Frontend

In another terminal:
```bash
cd frontend
flutter run -d emulator-5554
```

### Step 4: Test 2-User Conversation

**User 1: Alice**

1. Login with: `alice@example.com` / `alice123`
2. Tap "Invitations" tab
3. Send invitation to `bob@example.com`

**User 2: Bob** (need two instances running)

Launch second emulator or use physical device:
```bash
flutter run -d <device-id>
```

1. Login with: `bob@example.com` / `bob123`
2. Tap "Invitations" tab
3. See Alice's invitation
4. Tap "Accept"

**Back to Alice**

1. Tap "Chat List" tab (once implemented)
2. Should see new chat with Bob

**Alice sends message**

1. Tap on Bob's chat
2. Type: "Hey Bob, how are you?"
3. Tap Send button
4. Message appears immediately in Alice's bubble (right side)

**Bob receives message**

1. If Bob is in the chat → message appears immediately in left bubble (Bob's UI shows received)
2. If Bob is in chat list → refresh or wait for WebSocket push → new message badge on Bob's chat

**Bob replies**

1. Type: "I'm doing great, thanks for asking!"
2. Tap Send
3. Message appears in Bob's bubble (right for Bob, left for Alice)

**Alice sees reply**

1. If Alice is in chat → message appears in left bubble
2. Alert badge or notification (if implemented)

---

## Validation Checklist

### P1: View Chat List (Acceptance Criteria)

- [ ] Chat list displays all accepted chats (no archived)
- [ ] Chats sorted by most recent message first
- [ ] Friend's name displayed for each chat
- [ ] Last message snippet visible
- [ ] Timestamp shown (e.g., "14:30" or "Mar 15")
- [ ] Empty state message if no chats: "No chats yet. Accept an invitation to start messaging!"
- [ ] Chat list updates when user accepts new invitation

### P1: Send & Receive Messages

- [ ] User can tap into a chat and see message history
- [ ] User can type and send a message
- [ ] Sent message appears immediately with timestamp
- [ ] Recipient sees received message with sender name and timestamp
- [ ] Message appears in real-time if recipient is viewing chat
- [ ] Message history persists if app closes/reopens
- [ ] Messages display with correct encryption (encrypted content not visible)

### P2: Archive Chats

- [ ] User can long-press/swipe to reveal "Archive" option
- [ ] Tapping "Archive" removes chat from main list
- [ ] Archived chat accessible in "Archived" section/tab
- [ ] User can tap "Unarchive" to restore chat
- [ ] If message arrives in archived chat, notification sent but chat remains archived

---

## Terminal Testing (Without UI)

Use Python test script or `curl` for backend validation:

```bash
# Get JWT token
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice", "password":"alice123"}'

# Response: { "token": "eyJhbGc..." }

# Get Alice's chats
curl -X GET http://localhost:8081/api/chats \
  -H "Authorization: Bearer eyJhbGc..."

# Send message to Bob
curl -X POST http://localhost:8081/api/chats/{chat-id}/messages \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{"encrypted_content":"ChaCha20Base64==","created_at":"2026-03-15T10:00:00Z"}'
```

---

## Debugging

### Backend Issues

**Port 8081 not reachable from emulator**

```bash
# In WSL2 terminal:
wsl hostname -I
# Should output 172.31.195.26 or similar

# Test from emulator:
adb shell curl -X GET http://172.31.195.26:8081/health
```

**Database connection error**

```bash
# Verify PostgreSQL is running:
docker-compose ps
# Expected: postgres service RUNNING

# Check logs:
docker-compose logs postgres
```

### Frontend Issues

**"user_id not available" error on message send**

```
This means AuthProvider didn't set the user context before
ChatApiService tried to fetch chats. In app.dart, ensure:
  - onAuthSuccess callback increments chatsCacheInvalidatorProvider
  - app.dart is a ConsumerStatefulWidget listening to auth changes
```

**WebSocket not connecting (message delay >2s)**

```
Expected: WebSocket auto-reconnect on timeout
Fallback: HTTP polling kicks in
Check: WebSocketService provider lifecycle (should connect on app open)
```

---

## Performance Baselines (After Implementation)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Chat list load time | <500ms | Time from tap to full list rendered |
| Message delivery | <2s end-to-end | Send on Alice → Appears on Bob's device |
| Message history fetch | <500ms | Load 20 messages from DB → UI |
| Real-time update | <1s | Message arrives via WebSocket → User sees |

---

## Cleanup After Testing

Remove test chats (optional):

```bash
# In PostgreSQL:
DELETE FROM messages WHERE chat_id IN (
  SELECT id FROM chats WHERE participant_1_id = '<alice-id>'
);
DELETE FROM chats WHERE participant_1_id = '<alice-id>';
```

Reset frontend:

```bash
flutter clean
flutter pub get
```
