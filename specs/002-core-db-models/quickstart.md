# Phase 1 Quickstart: Core Database Models

**Date**: 2026-03-10  
**Feature**: 002-core-db-models  
**Status**: Ready for Implementation

## Overview

This guide demonstrates how to use the Core Database Models and run migrations. The database schema is managed by Serverpod migrations in the `backend/migrations/` directory.

## Setup

### Prerequisites

- Dart 3.5+
- PostgreSQL 13+ running (via docker-compose)
- Serverpod backend initialized

### Start Backend

```bash
# Start PostgreSQL and Serverpod backend
cd /home/katikraavi/mobile-messenger
docker-compose up

# Output should show:
# ✓ Serverpod started on port 8081
# ✓ [INFO] Health check endpoint available at http://localhost:8081/health
```

### Verify Database

```bash
# Connect to PostgreSQL to verify schema
psql -h localhost -U messenger_user -d messenger_db -c "\dt"

# Should show tables: user, chat, chat_member, message, invite
```

## Migration Workflow

### Running Migrations

Migrations run automatically on Serverpod startup. To manually trigger:

```bash
cd backend

# Run pending migrations
dart run bin/server.dart

# Verify migrations completed by checking logs
# Look for: "Database migrations completed successfully"
```

### Creating User

```dart
// In Serverpod endpoint

final userService = UserService();
final newUser = await userService.createUser(
  email: 'alice@example.com',
  username: 'alice',
  passwordHash: bcryptHash('secure_password'), // Use bcrypt
);

print('Created user: ${newUser.id}');
```

### Creating Chat

```dart
// Create one-on-one chat
final chatService = ChatService();
final chat = await chatService.createChat();

// Add members
await chatService.addMember(chat.id, aliceUserId);
await chatService.addMember(chat.id, bobUserId);

print('Chat ${chat.id} created with 2 members');
```

### Sending Message

```dart
// Encrypt message before storing
final cryptography = Cryptography();
final encryptedContent = await cryptography.encryptMessage(
  'Hello, Bob!',
  symmetricKey, // Managed by application
);

// Create message
final messageService = MessageService();
final message = await messageService.createMessage(
  chatId: chatId,
  senderId: aliceUserId,
  encryptedContent: encryptedContent,
);

print('Message sent: ${message.id}');
```

### Querying Messages

```dart
// Get messages in a chat (paginated)
const pageSize = 50;
final messages = await messageService.getMessagesByChatId(
  chatId,
  limit: pageSize,
  offset: 0,
);

// Decrypt messages for display
for (final msg in messages) {
  final decrypted = await cryptography.decryptMessage(
    msg.encryptedContent,
    symmetricKey,
  );
  print('${msg.senderId}: $decrypted');
}
```

### Updating Message Status

```dart
// Mark message as delivered
await messageService.updateMessageStatus(
  messageId: message.id,
  status: MessageStatus.delivered,
);

// Later, mark as read
await messageService.updateMessageStatus(
  messageId: message.id,
  status: MessageStatus.read,
);
```

### Sending Invitation

```dart
// Send friend invitation
final inviteService = InviteService();
final invite = await inviteService.createInvite(
  senderId: aliceUserId,
  receiverId: bobUserId,
);

print('Invitation sent: ${invite.id}');
```

### Accepting Invitation

```dart
// Accept invitation
await inviteService.acceptInvite(inviteId);

// This creates implicit friend chat or marks friendship status
```

### Archiving Chat

```dart
// Archive chat for user
await chatService.archiveChat(chatId, userId);

// Unarchive
await chatService.unarchiveChat(chatId, userId);

// Query active chats (excludes archived)
final activeChats = await chatService.getUserActiveChats(userId);
```

## Schema Validation

### Using psql

```bash
# List all tables
\dt

# Describe User table
\d "user"

# Describe indexes
\di

# Check foreign keys
SELECT constraint_name, table_name, column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'public';
```

### Using SQL Queries

```sql
-- Verify unique constraints
SELECT *
FROM information_schema.table_constraints
WHERE constraint_type = 'UNIQUE' AND table_schema = 'public';

-- Verify indexes
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public';

-- Check enum types
SELECT enumtypid, enumlabel
FROM pg_enum;
```

## Testing Examples

### Unit Test for User Model

```dart
import 'package:test/test.dart';

void main() {
  test('User model serialization', () {
    final user = User(
      id: 'uuid-123',
      email: 'alice@example.com',
      username: 'alice',
      passwordHash: 'hash',
      emailVerified: false,
      createdAt: DateTime.now(),
    );
    
    final json = user.toJson();
    expect(json['email'], 'alice@example.com');
    
    final restored = User.fromJson(json);
    expect(restored.id, user.id);
  });
}
```

### Integration Test for Message Creation

```dart
import 'package:test/test.dart';

void main() {
  test('Create and retrieve message', () async {
    // Setup: Create users and chat
    final alice = await userService.createUser(...);
    final bob = await userService.createUser(...);
    final chat = await chatService.createChat();
    await chatService.addMember(chat.id, alice.id);
    await chatService.addMember(chat.id, bob.id);
    
    // Action: Create message
    final msg = await messageService.createMessage(
      chatId: chat.id,
      senderId: alice.id,
      encryptedContent: encryptedText,
    );
    
    // Assert: Verify message exists with correct properties
    expect(msg.status, MessageStatus.sent);
    expect(msg.senderId, alice.id);
    expect(msg.chatId, chat.id);
    
    // Cleanup: Delete test data (automatic via CASCADE)
  });
}
```

## Performance Tuning

### Query Performance

```sql
-- Check query plan
EXPLAIN ANALYZE
SELECT * FROM message
WHERE chat_id = 'chat-uuid'
ORDER BY created_at DESC
LIMIT 50;

-- Should use index on (chat_id, created_at DESC)
```

### Connection Pooling

Configure in Serverpod `config/server.yaml`:

```yaml
database:
  host: postgres
  port: 5432
  name: messenger_db
  user: messenger_user
  password: messenger_password
  poolSize: 10
  ssl: false  # true in production
```

## Troubleshooting

### Migration Failed

```
Error: Failed to execute migration 001_create_users_table.dart
```

**Solution**: Check PostgreSQL logs and ensure table doesn't already exist

```bash
docker logs messenger-postgres | tail -50
```

### Connection Refused

```
Error: Could not connect to database at localhost:5432
```

**Solution**: Verify PostgreSQL container is running

```bash
docker-compose ps
docker-compose logs postgres
```

### Unique Constraint Violated

```
Error: Duplicate key value violates unique constraint "idx_user_email"
```

**Solution**: Email already exists in system

```sql
SELECT * FROM "user" WHERE email = 'alice@example.com';
-- Delete if test data
DELETE FROM "user" WHERE email = 'alice@example.com';
```

## Next Steps

After successful migration and schema verification:

1. **Implement Services**: Create database access layer in `backend/lib/src/services/`
2. **Create Endpoints**: Implement REST/RPC endpoints in `backend/lib/src/endpoints/`
3. **Add Tests**: Write unit and integration tests
4. **Connect Frontend**: Integrate with Flutter UI layer
