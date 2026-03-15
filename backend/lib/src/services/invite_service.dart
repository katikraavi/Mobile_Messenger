import 'package:postgres/postgres.dart';
import '../models/chat_invite.dart';
import 'package:uuid/uuid.dart';

/// Database-backed service for managing chat invitations
/// 
/// Handles business logic:
/// - Preventing self-invites (FR-001)
/// - Preventing duplicate pending invites
/// - Validating users exist and aren't already chatting (FR-002)
/// - CRUD operations on invitations (FR-003, FR-007, FR-008)
class InviteService {
  final Connection connection;

  InviteService(this.connection);

  /// Send a new invitation from sender to recipient (FR-001, FR-002, FR-003)
  Future<ChatInvite> sendInvite({
    required String senderId,
    required String recipientId,
  }) async {
    // Validation: No self-invites (FR-001)
    if (senderId == recipientId) {
      throw Exception('Cannot send invitation to yourself');
    }

    // Validation: Check both users exist
    final senderExists = await _userExists(senderId);
    if (!senderExists) {
      throw Exception('Sender user not found');
    }

    final recipientExists = await _userExists(recipientId);
    if (!recipientExists) {
      throw Exception('Recipient user not found');
    }

    // Validation: Check if users already have a chat (FR-002)
    final existingChat = await _chatExistsBetweenUsers(senderId, recipientId);
    if (existingChat) {
      throw Exception('Users already have an active chat');
    }

    // Validation: Check for existing pending invite
    final existingPending = await _getExistingPendingInvite(senderId, recipientId);
    if (existingPending != null) {
      throw Exception('Pending invitation already exists');
    }

    // Create new invite (FR-003)
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();

    await connection.execute(
      Sql.named(
        '''INSERT INTO chat_invites (id, sender_id, recipient_id, status, created_at, updated_at)
           VALUES (@id, @sender_id, @recipient_id, @status, @created_at, @updated_at)''',
      ),
      parameters: {
        'id': id,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'status': 'pending',
        'created_at': now,
        'updated_at': now,
      },
    );

    return ChatInvite(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  /// Get all pending invitations for a recipient (FR-004)
  Future<List<Map<String, dynamic>>> getPendingInvites(String recipientId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT 
             i.id, i.sender_id, i.recipient_id, i.status, 
             i.created_at, i.updated_at, i.deleted_at,
             u.username, u.avatar_url
           FROM chat_invites i
           JOIN "user" u ON i.sender_id = u.id
           WHERE i.recipient_id = @recipient_id 
             AND i.status = 'pending'
             AND i.deleted_at IS NULL
           ORDER BY i.created_at DESC''',
      ),
      parameters: {'recipient_id': recipientId},
    );

    return result.map((row) => row.toColumnMap() as Map<String, dynamic>).toList();
  }

  /// Get all sent invitations for a sender (FR-015)
  Future<List<Map<String, dynamic>>> getSentInvites(String senderId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT 
             i.id, i.sender_id, i.recipient_id, i.status, 
             i.created_at, i.updated_at, i.deleted_at
           FROM chat_invites i
           WHERE i.sender_id = @sender_id 
             AND i.deleted_at IS NULL
           ORDER BY i.created_at DESC''',
      ),
      parameters: {'sender_id': senderId},
    );

    return result.map((row) => row.toColumnMap() as Map<String, dynamic>).toList();
  }

  /// Get count of pending invitations for a recipient (for badge - FR-012, FR-014)
  Future<int> getPendingInviteCount(String recipientId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT COUNT(*) as count
           FROM chat_invites
           WHERE recipient_id = @recipient_id 
             AND status = 'pending'
             AND deleted_at IS NULL''',
      ),
      parameters: {'recipient_id': recipientId},
    );

    final row = result.first.toColumnMap();
    return (row['count'] as int?) ?? 0;
  }

  /// Accept an invitation - mark as accepted and creates a chat (FR-005)
  Future<ChatInvite> acceptInvite(String inviteId) async {
    final invite = await _getInviteById(inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }

    if (invite.status != 'pending') {
      throw Exception('Invite is no longer pending');
    }

    final now = DateTime.now().toUtc();
    
    // Update invite status to accepted and mark deleted (FR-008: remove from pending)
    await connection.execute(
      Sql.named(
        '''UPDATE chat_invites 
           SET status = @status, updated_at = @updated_at, deleted_at = @deleted_at
           WHERE id = @id''',
      ),
      parameters: {
        'id': inviteId,
        'status': 'accepted',
        'updated_at': now,
        'deleted_at': now,
      },
    );

    return ChatInvite(
      id: invite.id,
      senderId: invite.senderId,
      recipientId: invite.recipientId,
      status: 'accepted',
      createdAt: invite.createdAt,
      updatedAt: now,
      deletedAt: now,
    );
  }

  /// Decline an invitation (FR-011)
  Future<ChatInvite> declineInvite(String inviteId) async {
    final invite = await _getInviteById(inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }

    if (invite.status != 'pending') {
      throw Exception('Invite is no longer pending');
    }

    final now = DateTime.now().toUtc();

    // Update invite status to declined and mark deleted (FR-008: remove from pending)
    await connection.execute(
      Sql.named(
        '''UPDATE chat_invites 
           SET status = @status, updated_at = @updated_at, deleted_at = @deleted_at
           WHERE id = @id''',
      ),
      parameters: {
        'id': inviteId,
        'status': 'declined',
        'updated_at': now,
        'deleted_at': now,
      },
    );

    return ChatInvite(
      id: invite.id,
      senderId: invite.senderId,
      recipientId: invite.recipientId,
      status: 'declined',
      createdAt: invite.createdAt,
      updatedAt: now,
      deletedAt: now,
    );
  }

  // Private helper methods

  Future<bool> _userExists(String userId) async {
    final result = await connection.execute(
      Sql.named('SELECT 1 FROM "user" WHERE id = @id LIMIT 1'),
      parameters: {'id': userId},
    );
    return result.isNotEmpty;
  }

  Future<bool> _chatExistsBetweenUsers(String userId1, String userId2) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT 1 FROM chat 
           WHERE (participant1_id = @user1 AND participant2_id = @user2)
              OR (participant1_id = @user2 AND participant2_id = @user1)
           LIMIT 1''',
      ),
      parameters: {'user1': userId1, 'user2': userId2},
    );
    return result.isNotEmpty;
  }

  Future<ChatInvite?> _getExistingPendingInvite(String senderId, String recipientId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT * FROM chat_invites 
           WHERE sender_id = @sender_id 
             AND recipient_id = @recipient_id 
             AND status = 'pending'
             AND deleted_at IS NULL
           LIMIT 1''',
      ),
      parameters: {'sender_id': senderId, 'recipient_id': recipientId},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();
    return ChatInvite(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      recipientId: row['recipient_id'] as String,
      status: row['status'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }

  Future<ChatInvite?> _getInviteById(String inviteId) async {
    final result = await connection.execute(
      Sql.named('SELECT * FROM chat_invites WHERE id = @id LIMIT 1'),
      parameters: {'id': inviteId},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();
    return ChatInvite(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      recipientId: row['recipient_id'] as String,
      status: row['status'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }
}
