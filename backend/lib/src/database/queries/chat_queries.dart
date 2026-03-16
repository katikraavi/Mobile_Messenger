import 'package:postgres/postgres.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';

/// Database query helpers for chat operations
/// 
/// Provides SQL queries optimized with appropriate indexes for common operations:
/// - Fetching active chats for a user (uses idx_chats_participant_*_active indexes)
/// - Fetching message history (uses idx_messages_chat_created index)
class ChatQueries {
  /// Get all active (unarchived) chats for a user with optimal query plan
  /// 
  /// Uses indexed query: idx_chats_participant_*_active
  /// Returns chats sorted by updated_at DESC for recency-based UX
  /// 
  /// Parameters:
  /// - connection: Database connection
  /// - userId: User ID to fetch chats for
  /// - limit: Maximum chats to return
  /// - offset: Pagination offset
  /// 
  /// Returns: List of Chat objects
  static Future<List<Chat>> getActiveChatsByUser(
    Connection connection,
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    const query = '''
      SELECT id, participant_1_id, participant_2_id, 
             is_participant_1_archived, is_participant_2_archived,
             created_at, updated_at
      FROM chats
      WHERE (participant_1_id = @userId AND is_participant_1_archived = FALSE)
         OR (participant_2_id = @userId AND is_participant_2_archived = FALSE)
      ORDER BY updated_at DESC
      LIMIT @limit OFFSET @offset
    ''';

    final result = await connection.query(
      query,
      substitutionValues: {
        'userId': userId,
        'limit': limit,
        'offset': offset,
      },
    );

    return result.map((row) => _rowToChat(row)).toList();
  }

  /// Get count of active chats for a user (for pagination)
  /// 
  /// Uses same indexed query but returns only COUNT
  static Future<int> getActiveChatCountByUser(
    Connection connection,
    String userId,
  ) async {
    const query = '''
      SELECT COUNT(*) FROM chats
      WHERE (participant_1_id = @userId AND is_participant_1_archived = FALSE)
         OR (participant_2_id = @userId AND is_participant_2_archived = FALSE)
    ''';

    final result = await connection.query(
      query,
      substitutionValues: {'userId': userId},
    );

    return result.first[0] as int;
  }

  /// Get messages for a chat with cursor-based pagination
  /// 
  /// Uses indexed query: idx_messages_chat_created
  /// Returns messages sorted by created_at DESC (newest first)
  /// Supports cursor pagination via beforeCursor (for infinite scrolling)
  /// 
  /// Parameters:
  /// - connection: Database connection
  /// - chatId: Chat ID to fetch messages from
  /// - limit: Maximum messages to return
  /// - beforeCursor: Optional timestamp to fetch messages before (for pagination)
  /// 
  /// Returns: List of Message objects
  static Future<List<Message>> getMessagesByChatId(
    Connection connection,
    String chatId, {
    int limit = 20,
    DateTime? beforeCursor,
  }) async {
    String query = '''
      SELECT id, chat_id, sender_id, encrypted_content, created_at
      FROM messages
      WHERE chat_id = @chatId
    ''';

    final substitutionValues = {
      'chatId': chatId,
      'limit': limit,
    };

    if (beforeCursor != null) {
      query += ' AND created_at < @beforeCursor';
      substitutionValues['beforeCursor'] = beforeCursor;
    }

    query += ' ORDER BY created_at DESC LIMIT @limit';

    final result = await connection.query(
      query,
      substitutionValues: substitutionValues,
    );

    return result.map((row) => _rowToMessage(row)).toList();
  }

  /// Get count of messages in a chat
  static Future<int> getMessageCountByChat(
    Connection connection,
    String chatId,
  ) async {
    const query = '''
      SELECT COUNT(*) FROM messages WHERE chat_id = @chatId
    ''';

    final result = await connection.query(
      query,
      substitutionValues: {'chatId': chatId},
    );

    return result.first[0] as int;
  }

  /// Get recent messages from a chat (for display)
  /// 
  /// Fetches the most recent N messages from a chat without pagination.
  /// Ordered by created_at DESC (newest first).
  /// Useful for preview/display purposes.
  /// 
  /// Parameters:
  /// - connection: Database connection
  /// - chatId: Chat ID
  /// - count: Number of recent messages to fetch (default: 1 for preview)
  /// 
  /// Returns: List of Message objects in reverse chronological order
  static Future<List<Message>> getRecentMessagesByChat(
    Connection connection,
    String chatId, {
    int count = 1,
  }) async {
    const query = '''
      SELECT id, chat_id, sender_id, encrypted_content, created_at
      FROM messages
      WHERE chat_id = @chatId
      ORDER BY created_at DESC
      LIMIT @limit
    ''';

    final result = await connection.query(
      query,
      substitutionValues: {
        'chatId': chatId,
        'limit': count,
      },
    );

    return result.map((row) => _rowToMessage(row)).toList();
  }

  /// Check if a user is a participant in a chat
  /// 
  /// Uses index lookup for efficiency
  static Future<bool> isUserChatParticipant(
    Connection connection,
    String userId,
    String chatId,
  ) async {
    const query = '''
      SELECT 1 FROM chats
      WHERE id = @chatId 
        AND (participant_1_id = @userId OR participant_2_id = @userId)
      LIMIT 1
    ''';

    final result = await connection.query(
      query,
      substitutionValues: {
        'chatId': chatId,
        'userId': userId,
      },
    );

    return result.isNotEmpty;
  }

  /// Get other participant ID from a chat
  /// 
  /// Returns the participant ID that is NOT the provided userId
  /// Returns null if user is not a participant
  static Future<String?> getOtherParticipantId(
    Connection connection,
    String chatId,
    String userId,
  ) async {
    const query = '''
      SELECT CASE 
        WHEN participant_1_id = @userId THEN participant_2_id
        WHEN participant_2_id = @userId THEN participant_1_id
        ELSE NULL
      END as other_id
      FROM chats
      WHERE id = @chatId
    ''';

    final result = await connection.query(
      query,
      substitutionValues: {
        'chatId': chatId,
        'userId': userId,
      },
    );

    if (result.isEmpty) return null;
    return result.first[0] as String?;
  }

  /// Get all messages from a user within a chat
  /// 
  /// Useful for statistics or audit purposes
  /// Uses index: idx_messages_sender
  static Future<List<Message>> getMessagesBySender(
    Connection connection,
    String chatId,
    String senderId,
  ) async {
    const query = '''
      SELECT id, chat_id, sender_id, encrypted_content, created_at
      FROM messages
      WHERE chat_id = @chatId AND sender_id = @senderId
      ORDER BY created_at DESC
    ''';

    final result = await connection.query(
      query,
      substitutionValues: {
        'chatId': chatId,
        'senderId': senderId,
      },
    );

    return result.map((row) => _rowToMessage(row)).toList();
  }

  /// Helper: Convert database row to Chat model
  static Chat _rowToChat(List<dynamic> row) {
    return Chat(
      id: row[0] as String,
      participant1Id: row[1] as String,
      participant2Id: row[2] as String,
      isParticipant1Archived: row[3] as bool,
      isParticipant2Archived: row[4] as bool,
      createdAt: row[5] as DateTime,
      updatedAt: row[6] as DateTime,
    );
  }

  /// Helper: Convert database row to Message model
  static Message _rowToMessage(List<dynamic> row) {
    return Message(
      id: row[0] as String,
      chatId: row[1] as String,
      senderId: row[2] as String,
      encryptedContent: row[3] as String,
      createdAt: row[4] as DateTime,
    );
  }
}
