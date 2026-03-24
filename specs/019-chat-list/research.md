# Phase 0: Research Findings

**Purpose**: Resolve architectural unknowns identified in Technical Context and Constitution Check.  
**Date**: 2026-03-15  
**Status**: Complete

---

## 1. Real-Time Message Sync Strategy: WebSocket vs Polling

### Decision: WebSocket with JSON event streaming

**Rationale**:
- Flutter/Dart has excellent `web_socket_channel` package (async stream support)
- Riverpod manages WebSocket lifecycle (connect on app open, auto-reconnect)
- Message latency <2s requirement demands persistent connection, not polling overhead
- Architecture principle (II): Clear layer separation - WebSocket as dedicated real-time layer

**Alternative Rejected**: HTTP polling
- Would require $5-10 sec polling interval to avoid server load
- Violates <2s end-to-end latency goal
- Poor battery efficiency for mobile

**Alternative Rejected**: Serverpod built-in real-time (if applicable)
- Project uses custom Shelf microservice (not Serverpod ORM)
- WebSocket integration simpler with Shelf

### Implementation Pattern

**Backend (Shelf + Dart)**:
```dart
// WebSocket upgrade at /ws/messages
WebSocketHandler wsHandler = (WebSocket socket) {
  // Send chat event stream to client
  socket.add(jsonEncode({
    'type': 'message',
    'data': {'id': '...', 'chat_id': '...', 'encrypted_content': '...', 'created_at': '...'}
  }));
};
```

**Frontend (Flutter + Riverpod)**:
```dart
// WebSocketService provider manages connection lifecycle
final webSocketServiceProvider = Provider((ref) => WebSocketService());

// StreamProvider transforms WebSocket events into Riverpod streams
final messageStreamProvider = StreamProvider((ref) async* {
  final ws = ref.watch(webSocketServiceProvider);
  async for (var message in ws.messageStream) {
    yield message;
  }
});

// FutureProvider for initial chat list load (HTTP)
final chatsProvider = FutureProvider((ref) => chatService.fetchChats());
```

---

## 2. End-to-End Encryption: Key Exchange & Implementation

### Decision: Pre-shared keys via invitation flow + cryptography Dart package

**Rationale**:
- Constitution Principle I (Security-First): "Encryption library is cryptography, single source of truth"
- Existing invitation flow creates 1:1 relationship → opportunity to exchange keys
- `cryptography` package provides ChaCha20-Poly1305 (authenticated encryption) ✅
- Complexity: Acceptable for 2-user 1:1 chat MVP

**Key Exchange Timing**:
1. Alice sends invitation to Bob → Backend stores both users' public keys in `invites` table
2. Bob accepts invitation → Chat is created, both users download shared keys
3. Messages encrypted with shared session key (rotate if security requires later)

**Alternative Rejected**: Full Double Ratchet Protocol (Signal)
- Excessive complexity for v1 MVP
- Can upgrade in v2 if threat model demands

**Alternative Rejected**: Plaintext (security-first violation)
- Explicitly forbidden by Constitution Principle I

### Implementation Pattern

**Backend (encryption at rest)**:
```dart
// message_encryption_service.dart - single source of truth
final encryptedContent = await encryptMessage(
  plaintext: messageText,
  sharedKey: chacha20PolyKey,  // From invitation/chat establish
);
// Store encryptedContent (Base64) in messages.encrypted_content
```

**Frontend (E2E encryption)**:
```dart
// chat_detail_screen.dart - encrypt on send
final sendButton = FloatingActionButton(
  onPressed: () async {
    final encrypted = await messageEncryptionService.encryptMessage(
      plaintext: _textController.text,
      chatId: widget.chatId, // Retrieves chat's shared key
    );
    await ref.read(sendMessageProvider(widget.chatId).notifier).send(encrypted);
  },
);

// messages_provider.dart - decrypt on receive
.map((messages) => messages.map((m) async {
  final decrypted = await messageEncryptionService.decryptMessage(
    encrypted: m.encrypted_content,
    chatId: m.chat_id,
  );
  return m.copyWith(content: decrypted);
}).toList())
```

---

## 3. Message Persistence & Query Optimization

### Decision: PostgreSQL with cursor-based pagination, lazy-load on scroll

**Rationale**:
- Existing PostgreSQL setup with `users` and `invites` tables → extend schema
- <500ms chat list load = fetch 50 most-recent chats + last message snippet (indexed)
- <2s message sync = fetch chat history in 20-message batches on scroll

**Query Strategy**:

**Chat List Query** (PostgreSQL):
```sql
SELECT 
  c.id, c.participant_1_id, c.participant_2_id, 
  c.updated_at, c.is_participant_1_archived, c.is_participant_2_archived,
  (SELECT m.created_at, m.encrypted_content FROM messages m 
   WHERE m.chat_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message
FROM chats c
WHERE (c.participant_1_id = $1 AND c.is_participant_1_archived = FALSE)
   OR (c.participant_2_id = $1 AND c.is_participant_2_archived = FALSE)
ORDER BY c.updated_at DESC
LIMIT 50;
```
**Index**: `CREATE INDEX idx_chats_participant_1 ON chats(participant_1_id, updated_at DESC)`

**Message History Query** (Cursor-based pagination):
```sql
SELECT id, sender_id, encrypted_content, created_at 
FROM messages 
WHERE chat_id = $1 AND created_at < $2 
ORDER BY created_at DESC 
LIMIT 20;
```
**Index**: `CREATE INDEX idx_messages_chat_created ON messages(chat_id, created_at DESC)`

**Frontend Strategy** (Riverpod):
```dart
// messagesProvider watches both scroll position and cursor marker
final messagesProvider = FutureProvider.autoDispose.family((ref, String chatId) async {
  final cursor = ref.watch(messagesCursorProvider(chatId)); // Timestamp of oldest loaded
  return api.fetchMessages(chatId, beforeCursor: cursor, limit: 20);
});

// On scroll to bottom, update cursor to trigger load of older messages
onEndOfList() => ref.read(messagesCursorProvider(chatId).notifier).state = oldestMessageTimestamp;
```

---

## 4. Offline Message Queueing

### Decision: Local SQLite queue + retry on reconnect (Phase 2 if time permits)

**Rationale**:
- Constitution Principle V (Delivery Readiness): "offline-capable preferred"
- MVP (P1): Can launch without queueing if backend stays reliable
- Phase 2+: Add local queue when offline UX becomes critical
- Implementation: Minimal (ObjectBox or Drift for local SQLite)

**Architecture**:
1. When user sends message in offline state → Store in local queue table
2. When connection restored → Replay queue in order
3. Backend idempotency key prevents duplicates (chat_id + created_at + sender_id)

**Deferred to Phase 2** due to scope. MVP assumes connectivity.

---

## 5. Archive Feature: State Management Approach

### Decision: Archive flag on chats table, Riverpod filter provider

**Rationale**:
- Persistent state in database (`is_participant_1_archived`, `is_participant_2_archived`)
- Per-user archive (Alice archives chat ≠ Bob archives same chat)
- Riverpod selector filters: `active_chats_provider` vs `archived_chats_provider`

**Schema**:
```sql
ALTER TABLE chats ADD COLUMN is_participant_1_archived BOOLEAN DEFAULT FALSE;
ALTER TABLE chats ADD COLUMN is_participant_2_archived BOOLEAN DEFAULT FALSE;
```

**Frontend Filter** (Riverpod):
```dart
final activeChatProvider = FutureProvider((ref) async {
  final allChats = await ref.watch(chatsProvider.future);
  final userId = ref.watch(authProvider).user!.id;
  return allChats.where((chat) {
    final isArchived = (chat.participant_1_id == userId && chat.is_participant_1_archived)
                    || (chat.participant_2_id == userId && chat.is_participant_2_archived);
    return !isArchived;
  }).toList();
});

final archivedChatsProvider = FutureProvider((ref) async {
  // Inverse logic: only include archived
});
```

---

## 6. Real-Time Cache Invalidation on Login

### Decision: Existing `chatsCacheInvalidatorProvider` pattern (reuse from invitations)

**Rationale**:
- Already proven pattern in app: `invitesCacheInvalidatorProvider` with watcher
- Riverpod `StateProvider<int>` as version counter
- All chat providers watch the invalidator first: `ref.watch(chatsCacheInvalidatorProvider)`
- On login: increment invalidator in `app.dart` login callback

**Pattern**:
```dart
// providers/chat_cache_invalidator.dart
final chatsCacheInvalidatorProvider = StateProvider<int>((ref) => 0);

// Any chat provider
final chatsProvider = FutureProvider((ref) async {
  ref.watch(chatsCacheInvalidatorProvider); // Cache busts if incremented
  return api.fetchChats();
});

// In app.dart on login
onAuthSuccess: () {
  ref.read(chatsCacheInvalidatorProvider.notifier).state++;
  ref.read(invitesCacheInvalidatorProvider.notifier).state++;
}
```

---

## Summary of Design Decisions

| Area | Decision | Trade-off |
|------|----------|-----------|
| **Real-time sync** | WebSocket + Riverpod StreamProvider | Higher complexity than polling, but meets <2s latency |
| **Encryption** | ChaCha20-Poly1305 via pre-shared keys (invitation flow) | Not Signal protocol level, acceptable for MVP |
| **Message persistence** | PostgreSQL cursor pagination + indexes | Requires DB migration, not file-based |
| **Offline queueing** | Deferred to Phase 2 | MVP assumes connectivity |
| **Archive state** | Per-user archive flag + Riverpod filter | Requires schema change, but clean separation of concerns |
| **Cache invalidation** | Reuse invitations pattern (StateProvider watcher) | Proven, minimal new code |

All decisions align with project Constitution and technical constraints. Ready for Phase 1 design.
