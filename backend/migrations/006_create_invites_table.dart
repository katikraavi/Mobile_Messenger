import 'package:postgres/postgres.dart';

/// Migration: Create chat_invites table for user invitations to start 1-to-1 conversations
/// 
/// Spec: 017-chat-invitations
/// Design: Invites persist indefinitely until accepted, declined, or auto-removed when chat created
/// Soft delete strategy: deleted_at column for declined/removed invites
Future<void> up(Connection connection) async {
  // Create ENUM type for invite status
  await connection.execute('''
    CREATE TYPE invite_status AS ENUM ('pending', 'accepted', 'declined');
  ''').catchError((_) {
    // Type may already exist, ignore error
    return null;
  });

  // Create chat_invites table
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS chat_invites (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      sender_id UUID NOT NULL,
      recipient_id UUID NOT NULL,
      status invite_status NOT NULL DEFAULT 'pending',
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      deleted_at TIMESTAMP WITH TIME ZONE,
      
      CONSTRAINT fk_chat_invites_sender FOREIGN KEY (sender_id) 
        REFERENCES "user"(id) ON DELETE CASCADE,
      CONSTRAINT fk_chat_invites_recipient FOREIGN KEY (recipient_id) 
        REFERENCES "user"(id) ON DELETE CASCADE,
      
      CONSTRAINT sender_not_recipient CHECK (sender_id != recipient_id),
      CONSTRAINT updated_after_created CHECK (updated_at >= created_at)
    );
  ''');
  
  // Index: Query pending invites by recipient (for inbox)
  await connection.execute('''
    CREATE INDEX idx_chat_invites_recipient_status 
      ON chat_invites(recipient_id, status) 
      WHERE deleted_at IS NULL;
  ''');
  
  // Index: Query sent invites by sender (for sent list)
  await connection.execute('''
    CREATE INDEX idx_chat_invites_sender_status 
      ON chat_invites(sender_id, status) 
      WHERE deleted_at IS NULL;
  ''');
  
  // Unique constraint: Only one pending invite per sender-recipient pair
  await connection.execute('''
    CREATE UNIQUE INDEX idx_chat_invites_pending_unique 
      ON chat_invites(sender_id, recipient_id) 
      WHERE status = 'pending' AND deleted_at IS NULL;
  ''');
  
  print('[✓] Table created: chat_invites');
}

/// Rollback: Drop chat_invites table and invite_status type
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS chat_invites CASCADE;
  ''');
  
  await connection.execute('''
    DROP TYPE IF EXISTS invite_status CASCADE;
  ''');
  
  print('[✓] Table dropped: chat_invites');
}

/// Migration metadata
class Migration006 {
  static const String name = '006_create_invites_table';
  static const int version = 6;
  static const DateTime createdAt = DateTime(2026, 3, 10);
}
