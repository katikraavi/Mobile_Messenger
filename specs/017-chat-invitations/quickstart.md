# Quick Start Guide: Chat Invitations Feature

**Date**: 2026-03-15 | **Feature**: [017-chat-invitations](./spec.md)

---

## Overview

This guide helps developers get started implementing and testing the Chat Invitations feature. It covers:
1. **Backend setup** (Serverpod endpoints)
2. **Database migration** (PostgreSQL schema)
3. **Frontend setup** (Flutter UI + state)
4. **Testing** (unit + integration)
5. **Deployment** (Docker + APK)

---

## Part 1: Backend Setup (Serverpod)

### Prerequisites
- Dart 3.5+
- Serverpod installed
- PostgreSQL running (see docker-compose.yml)

### Step 1: Database Migration

**File**: `backend/migrations/006_create_invites_table.dart`

```dart
import 'package:serverpod_cli/src/generator/migration.dart';

class Migration000000000000000 extends Migration {
  @override
  Future<void> up(Session session) async {
    await session.db.execute('''
      CREATE TABLE chat_invites (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        sender_id UUID NOT NULL,
        recipient_id UUID NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'pending',
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        deleted_at TIMESTAMP WITH TIME ZONE,
        
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE,
        CHECK (sender_id != recipient_id),
        CHECK (status IN ('pending', 'accepted', 'declined')),
        UNIQUE(sender_id, recipient_id) WHERE status = 'pending'
      );

      CREATE INDEX idx_chat_invites_recipient_status 
        ON chat_invites(recipient_id, status) 
        WHERE deleted_at IS NULL AND status = 'pending';

      CREATE INDEX idx_chat_invites_sender_status 
        ON chat_invites(sender_id, status) 
        WHERE deleted_at IS NULL;
    ''');
  }

  @override
  Future<void> down(Session session) async {
    await session.db.execute('DROP TABLE IF EXISTS chat_invites CASCADE;');
  }
}
```

**Run migration**:
```bash
cd backend
serverpod db apply
```

### Step 2: Create Data Model

**File**: `backend/lib/src/models/chat_invite.dart`

```dart
import 'package:serverpod/serverpod.dart';

@DataModel()
@SerializableEntity()
class ChatInvite extends TableRow implements Serializable {
  @PrimaryKey()
  late String id;
  
  @Reference(
    onDelete: ReferenceAction.cascade,
    onUpdate: ReferenceAction.cascade,
  )
  late User sender;
  late String senderId;
  
  @Reference(
    onDelete: ReferenceAction.cascade,
    onUpdate: ReferenceAction.cascade,
  )
  late User recipient;
  late String recipientId;
  
  late String status; // 'pending', 'accepted', 'declined'
  late DateTime createdAt;
  late DateTime updatedAt;
  late DateTime? deletedAt;

  ChatInvite({
    this.id = '',
    required this.sender,
    required this.senderId,
    required this.recipient,
    required this.recipientId,
    this.status = 'pending',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) {
    this.createdAt = createdAt ?? DateTime.now().toUtc();
    this.updatedAt = updatedAt ?? DateTime.now().toUtc();
  }
}
```

**Generate serialization**:
```bash
cd backend
dart run build_runner build lib/src/models
```

### Step 3: Create Service

**File**: `backend/lib/src/services/invite_service.dart`

```dart
import 'package:serverpod/serverpod.dart';
import '../models/chat_invite.dart';

class InviteService {
  final Session session;
  InviteService(this.session);

  /// Send an invitation from sender to recipient
  Future<ChatInvite> sendInvite(String senderId, String recipientId) async {
    // Validate: not self-invite
    if (senderId == recipientId) {
      throw InvalidInputException('Cannot invite yourself');
    }

    // Validate: both users exist
    final sender = await session.db.findById<User>(senderId);
    final recipient = await session.db.findById<User>(recipientId);
    if (sender == null || recipient == null) {
      throw ForeignKeyException('User not found');
    }

    // Check: already chatting?
    final existingChat = await session.db.query<Chat>(
      where: (c) => (c.participants.contains(senderId) & 
                     c.participants.contains(recipientId)),
      limit: 1,
    );
    if (existingChat.isNotEmpty) {
      throw InvalidInputException('Already chatting with this user');
    }

    // Check: duplicate pending invite?
    final duplicate = await session.db.query<ChatInvite>(
      where: (i) => (i.senderId.equals(senderId) &
                    i.recipientId.equals(recipientId) &
                    i.status.equals('pending')),
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw ConflictException('Duplicate pending invitation');
    }

    // Create invite
    final invite = ChatInvite(
      id: uuid.v4(),
      sender: sender,
      senderId: senderId,
      recipient: recipient,
      recipientId: recipientId,
      status: 'pending',
    );

    await session.db.insert(invite);
    
    // TODO: Send push notification to recipient
    // pushNotificationService.sendNewInviteNotification(
    //   recipientId: recipientId,
    //   senderName: sender.name,
    // );

    return invite;
  }

  /// Get pending invites for recipient
  Future<List<ChatInvite>> getPendingInvites(String userId) async {
    return await session.db.query<ChatInvite>(
      where: (i) => (i.recipientId.equals(userId) &
                    i.status.equals('pending') &
                    i.deletedAt.isNull()),
      orderBy: (i) => i.createdAt,
      orderByDesc: true,
    );
  }

  /// Get sent invites from sender
  Future<List<ChatInvite>> getSentInvites(String userId) async {
    return await session.db.query<ChatInvite>(
      where: (i) => (i.senderId.equals(userId) &
                    i.deletedAt.isNull()),
      orderBy: (i) => i.createdAt,
      orderByDesc: true,
    );
  }

  /// Accept an invite and create chat
  Future<({ChatInvite invite, Chat chat})> acceptInvite(
    String inviteId, 
    String userId,
  ) async {
    final invite = await session.db.findById<ChatInvite>(inviteId);
    if (invite == null) {
      throw NotFoundException('Invite not found');
    }

    // Validate: user is recipient
    if (invite.recipientId != userId) {
      throw ForbiddenException('Not authorized');
    }

    // Validate: still pending
    if (invite.status != 'pending') {
      throw InvalidInputException('Invite not pending');
    }

    // Update invite status
    invite.status = 'accepted';
    invite.updatedAt = DateTime.now().toUtc();
    invite.deletedAt = DateTime.now().toUtc();
    await session.db.update(invite);

    // Create chat
    final chat = Chat(
      id: uuid.v4(),
      participants: [invite.senderId, invite.recipientId],
      createdAt: DateTime.now().toUtc(),
      inviteId: inviteId,
    );
    await session.db.insert(chat);

    // Remove any mutual pending invites
    await session.db.query<ChatInvite>(
      where: (i) => (i.status.equals('pending') &
                    ((i.senderId.equals(invite.senderId) & 
                      i.recipientId.equals(invite.recipientId)) |
                     (i.senderId.equals(invite.recipientId) & 
                      i.recipientId.equals(invite.senderId))) &
                    i.id.notEquals(inviteId)),
    ).then((mutualInvites) async {
      for (final mutual in mutualInvites) {
        mutual.deletedAt = DateTime.now().toUtc();
        await session.db.update(mutual);
      }
    });

    return (invite: invite, chat: chat);
  }

  /// Decline an invite
  Future<ChatInvite> declineInvite(String inviteId, String userId) async {
    final invite = await session.db.findById<ChatInvite>(inviteId);
    if (invite == null) {
      throw NotFoundException('Invite not found');
    }

    if (invite.recipientId != userId) {
      throw ForbiddenException('Not authorized');
    }

    if (invite.status != 'pending') {
      throw InvalidInputException('Invite not pending');
    }

    invite.status = 'declined';
    invite.updatedAt = DateTime.now().toUtc();
    invite.deletedAt = DateTime.now().toUtc();
    await session.db.update(invite);

    return invite;
  }
}
```

### Step 4: Create Endpoints

**File**: `backend/lib/src/endpoints/invites_endpoint.dart`

```dart
import 'package:serverpod/serverpod.dart';
import '../services/invite_service.dart';
import '../models/chat_invite.dart';

class InvitesEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  late InviteService inviteService;

  @override
  void initialize(Session session) {
    inviteService = InviteService(session);
  }

  /// POST /invites/send
  Future<ChatInvite> send(Session session, String recipientId) async {
    final userId = session.auth.userId;
    if (userId == null) throw UnauthenticatedException();

    return inviteService.sendInvite(userId, recipientId);
  }

  /// GET /invites/pending
  Future<List<ChatInvite>> getPending(Session session) async {
    final userId = session.auth.userId;
    if (userId == null) throw UnauthenticatedException();

    return inviteService.getPendingInvites(userId);
  }

  /// GET /invites/sent
  Future<List<ChatInvite>> getSent(Session session) async {
    final userId = session.auth.userId;
    if (userId == null) throw UnauthenticatedException();

    return inviteService.getSentInvites(userId);
  }

  /// POST /invites/accept
  Future<({ChatInvite invite, Chat chat})> accept(
    Session session,
    String inviteId,
  ) async {
    final userId = session.auth.userId;
    if (userId == null) throw UnauthenticatedException();

    return inviteService.acceptInvite(inviteId, userId);
  }

  /// POST /invites/decline
  Future<ChatInvite> decline(Session session, String inviteId) async {
    final userId = session.auth.userId;
    if (userId == null) throw UnauthenticatedException();

    return inviteService.declineInvite(inviteId, userId);
  }
}
```

---

## Part 2: Frontend Setup (Flutter)

### Prerequisites
- Flutter 3.41.4
- Riverpod packages (riverpod, hooks_riverpod, riverpod_generator)

### Step 1: Create Models

**File**: `frontend/lib/features/invitations/models/chat_invite_model.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_invite_model.freezed.dart';
part 'chat_invite_model.g.dart';

@freezed
class ChatInvite with _$ChatInvite {
  const factory ChatInvite({
    required String id,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String recipientId,
    required String recipientName,
    required String? recipientAvatarUrl,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ChatInvite;

  factory ChatInvite.fromJson(Map<String, dynamic> json) =>
      _$ChatInviteFromJson(json);

  const ChatInvite._();

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
}
```

### Step 2: Create API Service

**File**: `frontend/lib/features/invitations/services/invite_api_service.dart`

```dart
import 'package:dio/dio.dart';
import '../models/chat_invite_model.dart';

class InviteApiService {
  final Dio httpClient;
  static const baseUrl = '/api/invites';

  InviteApiService(this.httpClient);

  Future<ChatInvite> sendInvite(String recipientId) async {
    final response = await httpClient.post(
      '$baseUrl/send',
      data: {'recipientId': recipientId},
    );
    return ChatInvite.fromJson(response.data);
  }

  Future<List<ChatInvite>> fetchPendingInvites() async {
    final response = await httpClient.get('$baseUrl/pending');
    final data = response.data as List;
    return data.map((e) => ChatInvite.fromJson(e)).toList();
  }

  Future<List<ChatInvite>> fetchSentInvites() async {
    final response = await httpClient.get('$baseUrl/sent');
    final data = response.data as List;
    return data.map((e) => ChatInvite.fromJson(e)).toList();
  }

  Future<ChatInvite> acceptInvite(String inviteId) async {
    final response = await httpClient.post('$baseUrl/$inviteId/accept');
    return ChatInvite.fromJson(response.data['invite']);
  }

  Future<ChatInvite> declineInvite(String inviteId) async {
    final response = await httpClient.post('$baseUrl/$inviteId/decline');
    return ChatInvite.fromJson(response.data);
  }
}
```

### Step 3: Create Providers

**File**: `frontend/lib/features/invitations/providers/invites_provider.dart`

```dart
import 'package:riverpod/riverpod.dart';
import '../models/chat_invite_model.dart';
import '../services/invite_api_service.dart';

final inviteApiServiceProvider = Provider((ref) {
  return InviteApiService(ref.watch(httpClientProvider));
});

final pendingInvitesProvider = FutureProvider<List<ChatInvite>>((ref) async {
  final service = ref.watch(inviteApiServiceProvider);
  return service.fetchPendingInvites();
});

final sentInvitesProvider = FutureProvider<List<ChatInvite>>((ref) async {
  final service = ref.watch(inviteApiServiceProvider);
  return service.fetchSentInvites();
});

final inviteCountProvider = FutureProvider<int>((ref) async {
  final pending = await ref.watch(pendingInvitesProvider.future);
  return pending.length;
});
```

### Step 4: Create Screens

**File**: `frontend/lib/features/invitations/screens/invitations_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/chat_invite_model.dart';
import '../providers/invites_provider.dart';

class InvitationsScreen extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingInvites = ref.watch(pendingInvitesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invitations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingInvites(context, ref),
            _buildSentInvites(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingInvites(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingInvitesProvider);

    return pending.when(
      data: (invites) {
        if (invites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No pending invitations'),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];
            return _InviteCard(
              invite: invite,
              onAccept: () => _acceptInvite(context, ref, invite.id),
              onDecline: () => _declineInvite(context, ref, invite.id),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSentInvites(BuildContext context, WidgetRef ref) {
    final sent = ref.watch(sentInvitesProvider);

    return sent.when(
      data: (invites) {
        if (invites.isEmpty) {
          return Center(child: Text('No sent invitations'));
        }
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];
            return ListTile(
              title: Text(invite.recipientName),
              subtitle: Text(invite.status),
              trailing: Text(invite.createdAt.toString()),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }

  Future<void> _acceptInvite(BuildContext context, WidgetRef ref, String inviteId) async {
    // TODO: implement
  }

  Future<void> _declineInvite(BuildContext context, WidgetRef ref, String inviteId) async {
    // TODO: implement
  }
}

class _InviteCard extends StatelessWidget {
  final ChatInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteCard({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: invite.senderAvatarUrl != null
                      ? NetworkImage(invite.senderAvatarUrl!)
                      : null,
                  child: invite.senderAvatarUrl == null
                      ? Text(invite.senderName.substring(0, 1))
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.senderName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Sent ${invite.createdAt.toString()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDecline, child: Text('Decline')),
                ElevatedButton(onPressed: onAccept, child: Text('Accept')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Part 3: Testing

### Unit Tests

**File**: `backend/test/services/invite_service_test.dart`

```dart
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('InviteService', () {
    late InviteService service;
    late Session session;

    setUp(() async {
      // Initialize test session and service
    });

    test('sendInvite creates invite between users', () async {
      final senderId = uuid.v4();
      final recipientId = uuid.v4();

      final invite = await service.sendInvite(senderId, recipientId);

      expect(invite.senderId, senderId);
      expect(invite.recipientId, recipientId);
      expect(invite.status, 'pending');
    });

    test('sendInvite prevents self-invite', () async {
      expect(
        () => service.sendInvite(userId, userId),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('acceptInvite creates chat', () async {
      // Create invite
      // Accept it
      // Verify chat exists
    });
  });
}
```

### Widget Tests

**File**: `frontend/test/widget/invitations_screen_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvitationsScreen', () {
    testWidgets('shows pending invites', (WidgetTester tester) async {
      // Build the widget
      // Verify pending invites displayed
    });

    testWidgets('accept button calls acceptInvite', (WidgetTester tester) async {
      // Build widget
      // Tap accept button
      // Verify mutation called
    });
  });
}
```

---

## Part 4: Deployment

### Docker Compose

**File**: `docker-compose.yml` (update existing)

```yaml
services:
  messenger-postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: messenger_user
      POSTGRES_PASSWORD: messenger_password
      POSTGRES_DB: messenger_db
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  messenger-backend:
    build: ./backend
    depends_on:
      - messenger-postgres
    environment:
      DATABASE_URL: postgresql://messenger_user:messenger_password@messenger-postgres:5432/messenger_db
    ports:
      - "8080:8080"

volumes:
  postgres_data:
```

### Build & Run

```bash
# Build APK
cd frontend
flutter build apk --release

# Start backend
docker-compose up

# Run frontend on emulator
flutter run --release
```

---

## Next Steps

1. **Implement backend endpoints** (Serverpod service + endpoints)
2. **Implement frontend UI** (screens + state management)
3. **Write tests** (unit + widget + integration)
4. **Test manually** (2-user invite flow)
5. **Deploy** (APK + backend)

---

## Resources

- [Serverpod Docs](https://serverpod.dev/)
- [Flutter Riverpod](https://riverpod.dev/)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [API Contract](./contracts/invite_api.yaml)
- [State Models](./contracts/state_models.md)
- [Data Model](./data-model.md)

