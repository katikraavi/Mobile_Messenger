# Quickstart: Invitation Feature Implementation Guide

**Date**: March 15, 2026  
**Target Audience**: Developers implementing this feature  
**Time Estimate**: 4-6 days (including testing)

---

## Overview

This guide walks through implementing the invitation send/accept/reject/cancel feature end-to-end. The feature allows users to send invitations to initiate conversations, which recipients can accept or reject.

**Components**:
1. **Backend**: REST API endpoints in Serverpod
2. **Frontend**: Flutter UI screen + HTTP client + state management
3. **Database**: PostgreSQL `invites` table (already exists)

---

## Prerequisites

- Backend running: `docker-compose up` (with PostgreSQL)
- Frontend set up: Flutter with dependencies installed
- Test users seeded: alice, bob, charlie, diane (or your test user account names)
- Existing: User authentication (JWT tokens), user search, chat system

---

## Implementation Checklist

### Phase 1: Backend Implementation (Day 1-2)

#### Step 1.1: Verify Database Schema

Check the `invites` table structure:

```bash
docker-compose exec messenger-postgres psql -U messenger_user -d messenger_db -c "\dt invites"
docker-compose exec messenger-postgres psql -U messenger_user -d messenger_db -c "\d invites"
```

Expected columns:
- `id` (UUID, PRIMARY KEY)
- `sender_id` (UUID, FOREIGN KEY → users)
- `receiver_id` (UUID, FOREIGN KEY → users)
- `status` (TEXT: 'pending', 'accepted', 'rejected', 'canceled')
- `created_at` (TIMESTAMP)
- `responded_at` (TIMESTAMP, nullable)
- `canceled_at` (TIMESTAMP, nullable)

**If table doesn't exist**, create migration:

```dart
// lib/migrations/NNN_create_invites_table.dart
class CreateInvitesTableMigration extends Migration {
  @override
  Future<void> migrate(Database database) async {
    await database.transaction((tx) async {
      await tx.query('''
        CREATE TABLE invites (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          status TEXT NOT NULL DEFAULT 'pending' 
            CHECK (status IN ('pending', 'accepted', 'rejected', 'canceled')),
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          responded_at TIMESTAMP,
          canceled_at TIMESTAMP,
          CONSTRAINT no_self_invites CHECK (sender_id != receiver_id)
        );
        CREATE INDEX idx_invites_receiver_status 
          ON invites(receiver_id, status) 
          WHERE status = 'pending';
        CREATE INDEX idx_invites_sender_status 
          ON invites(sender_id, status);
      ''');
    });
  }

  @override
  Future<void> rollback(Database database) async {
    await database.query('DROP TABLE invites CASCADE;');
  }
}
```

Run migrations:
```bash
cd backend && dart run conduit:cli db upgrade
```

#### Step 1.2: Implement Database Models (DAO/ORM)

Create a model to represent invitation records:

```dart
// lib/src/models/invitation_model.dart
class InvitationModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String receiverId;
  final String recipientName;
  final String? recipientAvatarUrl;
  final String status; // 'pending', 'accepted', 'rejected', 'canceled'
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? canceledAt;

  InvitationModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.receiverId,
    required this.recipientName,
    this.recipientAvatarUrl,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.canceledAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatarUrl': senderAvatarUrl,
    'recipientId': receiverId,
    'recipientName': recipientName,
    'recipientAvatarUrl': recipientAvatarUrl,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
  };
}
```

#### Step 1.3: Implement Backend Endpoints

Add endpoints to `backend/lib/server.dart` in the Serverpod initialization:

```dart
/// 1. Create Invitation (POST /api/invites)
router.post('/api/invites', (request) async {
  final token = request.headers['Authorization']?.replaceFirst('Bearer ', '');
  if (token == null) return Response.authenticationRequired();

  final currentUserId = extractUserIdFromToken(token);
  final body = request.bodyAsJson;
  final receiverId = body['receiverId'];

  // Validate
  if (receiverId == currentUserId) {
    return Response(
      statusCode: 400,
      body: jsonEncode({'error': 'self_invitation', 'message': 'Cannot send invitation to yourself'}),
    );
  }

  // Check duplicate pending
  final existingResult = await database.query('''
    SELECT id FROM invites 
    WHERE sender_id = \$1 AND receiver_id = \$2 AND status = 'pending'
    LIMIT 1
  ''', [currentUserId, receiverId]);

  if (existingResult.isNotEmpty) {
    return Response(
      statusCode: 409,
      body: jsonEncode({
        'error': 'duplicate_invitation',
        'message': 'You have already sent a pending invitation to this user',
      }),
    );
  }

  // Create invitation
  final invitationId = Uuid().v4();
  await database.query('''
    INSERT INTO invites (id, sender_id, receiver_id, status, created_at)
    VALUES (\$1, \$2, \$3, 'pending', NOW())
  ''', [invitationId, currentUserId, receiverId]);

  // Fetch + return with sender/receiver details
  final result = await database.query('''
    SELECT i.id, i.sender_id, u.username as sender_name, u.profile_picture_url as sender_avatar,
           i.receiver_id, r.username as receiver_name, r.profile_picture_url as receiver_avatar,
           i.status, i.created_at, i.responded_at
    FROM invites i
    JOIN users u ON i.sender_id = u.id
    JOIN users r ON i.receiver_id = r.id
    WHERE i.id = \$1
  ''', [invitationId]);

  return Response(
    statusCode: 201,
    body: jsonEncode(_invitationRowToJson(result[0])),
  );
});

/// 2. Get Pending Invitations (GET /api/users/{userId}/invites/pending)
router.get('/api/users/:userId/invites/pending', (request) async {
  final token = request.headers['Authorization']?.replaceFirst('Bearer ', '');
  if (token == null) return Response.authenticationRequired();

  final currentUserId = extractUserIdFromToken(token);
  final userId = request.pathParameters['userId'];

  // Users can only see their own pending invitations
  if (userId != currentUserId) {
    return Response(
      statusCode: 403,
      body: jsonEncode({'error': 'forbidden', 'message': 'Cannot view another user\'s pending invitations'}),
    );
  }

  final results = await database.query('''
    SELECT i.id, i.sender_id, u.username as sender_name, u.profile_picture_url as sender_avatar,
           i.receiver_id, r.username as receiver_name, r.profile_picture_url as receiver_avatar,
           i.status, i.created_at, i.responded_at
    FROM invites i
    JOIN users u ON i.sender_id = u.id
    JOIN users r ON i.receiver_id = r.id
    WHERE i.receiver_id = \$1 AND i.status = 'pending'
    ORDER BY i.created_at DESC
  ''', [userId]);

  return Response(
    statusCode: 200,
    body: jsonEncode(results.map(_invitationRowToJson).toList()),
  );
});

/// 3. Get Sent Invitations (GET /api/users/{userId}/invites/sent)
router.get('/api/users/:userId/invites/sent', (request) async {
  final token = request.headers['Authorization']?.replaceFirst('Bearer ', '');
  if (token == null) return Response.authenticationRequired();

  final currentUserId = extractUserIdFromToken(token);
  final userId = request.pathParameters['userId'];

  if (userId != currentUserId) {
    return Response(statusCode: 403);
  }

  final results = await database.query('''
    SELECT i.id, i.sender_id, u.username as sender_name, u.profile_picture_url as sender_avatar,
           i.receiver_id, r.username as receiver_name, r.profile_picture_url as receiver_avatar,
           i.status, i.created_at, i.responded_at
    FROM invites i
    JOIN users u ON i.sender_id = u.id
    JOIN users r ON i.receiver_id = r.id
    WHERE i.sender_id = \$1
    ORDER BY i.created_at DESC
  ''', [userId]);

  return Response(
    statusCode: 200,
    body: jsonEncode(results.map(_invitationRowToJson).toList()),
  );
});

/// 4. Accept Invitation (POST /api/invites/{id}/accept)
router.post('/api/invites/:id/accept', (request) async {
  final invitationId = request.pathParameters['id'];
  final token = request.headers['Authorization']?.replaceFirst('Bearer ', '');
  if (token == null) return Response.authenticationRequired();

  final currentUserId = extractUserIdFromToken(token);

  // Start transaction for atomicity (accept + create chat)
  await database.transaction((tx) async {
    // Fetch invitation
    final result = await tx.query('''
      SELECT * FROM invites WHERE id = \$1
    ''', [invitationId]);

    if (result.isEmpty) {
      return Response(statusCode: 404);
    }

    final inv = result[0];
    if (inv['receiver_id'] != currentUserId) {
      return Response(statusCode: 403);
    }
    if (inv['status'] != 'pending') {
      return Response(statusCode: 400);
    }

    // Update invitation
    await tx.query('''
      UPDATE invites SET status = 'accepted', responded_at = NOW()
      WHERE id = \$1
    ''', [invitationId]);

    // Create chat (if doesn't already exist)
    final chatId = Uuid().v4();
    await tx.query('''
      INSERT INTO chats (id, participant_ids, created_at)
      VALUES (\$1, \$2, NOW())
    ''', [chatId, jsonEncode([inv['sender_id'], inv['receiver_id']])]);
  });

  // Fetch + return updated invitation
  final result = await database.query('''
    SELECT i.id, i.sender_id, u.username as sender_name, u.profile_picture_url as sender_avatar,
           i.receiver_id, r.username as receiver_name, r.profile_picture_url as receiver_avatar,
           i.status, i.created_at, i.responded_at
    FROM invites i
    JOIN users u ON i.sender_id = u.id
    JOIN users r ON i.receiver_id = r.id
    WHERE i.id = \$1
  ''', [invitationId]);

  return Response(
    statusCode: 200,
    body: jsonEncode(_invitationRowToJson(result[0])),
  );
});

// Similar implementations for: /decline, /cancel (DELETE)
```

#### Step 1.4: Test Backend Endpoints

```bash
# Terminal 1: Start backend
docker-compose up

# Terminal 2: Test with curl
# Alice sends invitation to Bob
curl -X POST http://localhost:8081/api/invites \
  -H "Authorization: Bearer alice_token" \
  -H "Content-Type: application/json" \
  -d '{"receiverId": "bob_uuid"}'

# Bob gets pending invitations
curl -X GET "http://localhost:8081/api/users/bob_uuid/invites/pending" \
  -H "Authorization: Bearer bob_token"

# Bob accepts
curl -X POST http://localhost:8081/api/invites/invitation_uuid/accept \
  -H "Authorization: Bearer bob_token"
```

---

### Phase 2: Frontend Implementation (Day 2-3)

#### Step 2.1: Create Invitation Model

```dart
// frontend/lib/features/invitations/models/chat_invite_model.dart
@freezed
class ChatInviteModel with _$ChatInviteModel {
  const factory ChatInviteModel({
    required String id,
    required String senderId,
    required String senderName,
    String? senderAvatarUrl,
    required String recipientId,
    required String recipientName,
    String? recipientAvatarUrl,
    required String status,
    required DateTime createdAt,
    DateTime? respondedAt,
  }) = _ChatInviteModel;

  factory ChatInviteModel.fromJson(Map<String, dynamic> json) =>
      _$ChatInviteModelFromJson(json);
}
```

#### Step 2.2: Create HTTP Service

```dart
// frontend/lib/features/invitations/services/invite_api_service.dart
class InviteApiService {
  final HttpClient httpClient;

  Future<List<ChatInviteModel>> getPendingInvites() async {
    final token = await _getAuthToken();
    final userId = await _getUserId();
    
    final response = await httpClient.get(
      Uri.parse('$baseUrl/users/$userId/invites/pending'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final list = jsonDecode(response.body) as List;
    return list.map((item) => ChatInviteModel.fromJson(item)).toList();
  }

  Future<List<ChatInviteModel>> getSentInvites() async {
    final token = await _getAuthToken();
    final userId = await _getUserId();
    
    final response = await httpClient.get(
      Uri.parse('$baseUrl/users/$userId/invites/sent'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final list = jsonDecode(response.body) as List;
    return list.map((item) => ChatInviteModel.fromJson(item)).toList();
  }

  Future<ChatInviteModel> sendInvitation(String recipientId) async {
    final token = await _getAuthToken();
    
    final response = await httpClient.post(
      Uri.parse('$baseUrl/invites'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'receiverId': recipientId}),
    );

    return ChatInviteModel.fromJson(jsonDecode(response.body));
  }

  Future<ChatInviteModel> acceptInvitation(String invitationId) async {
    final token = await _getAuthToken();
    
    final response = await httpClient.post(
      Uri.parse('$baseUrl/invites/$invitationId/accept'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return ChatInviteModel.fromJson(jsonDecode(response.body));
  }

  Future<ChatInviteModel> declineInvitation(String invitationId) async {
    final token = await _getAuthToken();
    
    final response = await httpClient.post(
      Uri.parse('$baseUrl/invites/$invitationId/decline'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return ChatInviteModel.fromJson(jsonDecode(response.body));
  }

  Future<ChatInviteModel> cancelInvitation(String invitationId) async {
    final token = await _getAuthToken();
    
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/invites/$invitationId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return ChatInviteModel.fromJson(jsonDecode(response.body));
  }

  Future<String> _getAuthToken() async {
    return await secureStorage.read(key: 'auth_token');
  }

  Future<String> _getUserId() async {
    return await secureStorage.read(key: 'user_id');
  }
}
```

#### Step 2.3: Create Riverpod Providers

```dart
// frontend/lib/features/invitations/providers/invites_provider.dart
final pendingInvitesProvider = FutureProvider<List<ChatInviteModel>>((ref) async {
  final service = ref.watch(inviteApiServiceProvider);
  return service.getPendingInvites();
});

final sentInvitesProvider = FutureProvider<List<ChatInviteModel>>((ref) async {
  final service = ref.watch(inviteApiServiceProvider);
  return service.getSentInvites();
});

final allInvitesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final pending = await ref.watch(pendingInvitesProvider.future);
  final sent = await ref.watch(sentInvitesProvider.future);
  return [
    ...pending.map((i) => {'type': 'incoming', 'data': i}),
    ...sent.map((i) => {'type': 'outgoing', 'data': i}),
  ];
});
```

#### Step 2.4: Build UI Screen

```dart
// frontend/lib/features/invitations/screens/invitations_screen.dart
class InvitationsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allInvites = ref.watch(allInvitesProvider);

    return allInvites.when(
      data: (items) => _UnifiedInvitationsList(items: items),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }
}

class _UnifiedInvitationsList extends ConsumerWidget {
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isIncoming = item['type'] == 'incoming';
        final invite = item['data'] as ChatInviteModel;

        return InviteCard(
          invite: invite,
          isIncoming: isIncoming,
          onAccept: isIncoming 
            ? () => ref.read(inviteApiServiceProvider).acceptInvitation(invite.id)
            : null,
          onDecline: isIncoming
            ? () => ref.read(inviteApiServiceProvider).declineInvitation(invite.id)
            : null,
          onCancel: !isIncoming
            ? () => ref.read(inviteApiServiceProvider).cancelInvitation(invite.id)
            : null,
        );
      },
    );
  }
}
```

#### Step 2.5: Test Frontend

```bash
cd frontend && flutter run -d linux

# Test flow:
# 1. Log in as alice
# 2. Send invitation to bob (via profile or button)
# 3. Log out, log in as bob
# 4. Verify invitation appears in pending list
# 5. Accept invitation
# 6. Verify invitation moves to accepted status
# 7. Verify new chat created in chat list
```

---

### Phase 3: Integration Testing (Day 3-4)

#### Unit Tests

```dart
// frontend/test/features/invitations/
void main() {
  test('Invitation models deserialize correctly', () {
    final json = {
      'id': 'test-id',
      'senderId': 'alice-id',
      'senderName': 'alice',
      'status': 'pending',
      'createdAt': '2026-03-15T13:47:00Z',
    };
    final invite = ChatInviteModel.fromJson(json);
    expect(invite.status, 'pending');
  });
}
```

#### Widget Tests

```dart
void main() {
  testWidgets('InvitationsScreen shows pending invites', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderContainer(
        overrides: [
          pendingInvitesProvider.overrideWithValue(AsyncValue.data([testInvite])),
        ],
        child: MaterialApp(home: InvitationsScreen()),
      ),
    );
    expect(find.text('alice'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets); // Accept/Decline buttons
  });
}
```

#### Integration Tests (Two-Device)

```bash
# Terminal 1
flutter run -d linux --target=test_driver/app.dart &

# Terminal 2
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/invitations_flow_test.dart
```

```dart
// integration_test/invitations_flow_test.dart
void main() {
  group('Invitations Flow', () {
    testWidgets('Alice sends invitation to Bob and Bob accepts', (WidgetTester tester) async {
      // 1. Alice: Log in
      await loginAs(tester, 'alice');

      // 2. Alice: Send invitation to Bob
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.typeText(find.byType(TextField), 'bob');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation sent'), findsOneWidget);

      // 3. Bob: Log in
      await logout(tester);
      await loginAs(tester, 'bob');

      // 4. Bob: Accept invitation
      await tester.tap(find.byIcon(Icons.inbox));
      expect(find.text('alice'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      // 5. Verify: Chat created
      expect(find.byType(ChatScreen), findsOneWidget);
    });
  });
}
```

---

### Phase 4: Documentation & Deployment (Day 4)

#### Update README

Add section to `frontend/README.md` and `backend/README.md`:

```markdown
## Invitation Feature

Users can send invitations to initiate conversations.

### API Endpoints
- POST /api/invites - Send invitation
- GET /api/users/{userId}/invites/pending - Get pending invites
- GET /api/users/{userId}/invites/sent - Get sent invites
- POST /api/invites/{id}/accept - Accept invitation
- POST /api/invites/{id}/decline - Reject invitation
- DELETE /api/invites/{id} - Cancel invitation

### Testing
See `INVITE_TESTING_GUIDE.md` for manual testing procedures.
```

#### Deploy

```bash
# Rebuild backend
docker-compose down
docker-compose build --no-cache serverpod
docker-compose up -d

# Test
flutter run -d linux
```

---

## Success Criteria Checklist

Before marking feature complete:

- [ ] Backend endpoints all implemented and tested with curl
- [ ] Frontend UI screen displays pending and sent invitations correctly
- [ ] Accept/Decline buttons work correctly
- [ ] New chat created when invitation accepted
- [ ] Cancel button removes invitation from both users' lists
- [ ] Unit tests pass (90%+ code coverage)
- [ ] Widget tests pass
- [ ] Integration test: Two-device test passes
- [ ] No data loss on concurrent operations
- [ ] Performance: All operations <2 seconds (SC-001 to SC-003)
- [ ] Android APK builds successfully
- [ ] README updated with instructions

---

## Troubleshooting

**Q: "duplicate_invitation" error when sending**
A: Check backend state; clear invites table if testing: `DELETE FROM invites;`

**Q: Frontend doesn't see new invitations**
A: Refresh manually or wait for polling interval; check auth token freshness

**Q: Accept button doesn't appear**
A: Verify `isIncoming` logic; check Riverpod provider is returning correct data

**Q: Chat not created after accept**
A: Check backend transaction; verify chats table exists; review Azure logs

---

## References

- Full API contract: [contracts/api.md](./contracts/api.md)
- Data model: [data-model.md](./data-model.md)
- Research: [research.md](./research.md)
- Feature spec: [spec.md](./spec.md)
