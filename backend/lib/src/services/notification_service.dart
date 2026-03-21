import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';

import 'chat_service.dart';

typedef Connection = PostgreSQLConnection;

/// Stores device tokens and sends push notifications when the backend is configured.
class NotificationService {
  NotificationService(this.connection, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final Connection connection;
  final http.Client _httpClient;

  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    String? platform,
  }) async {
    await connection.execute(
      '''
      INSERT INTO push_device_tokens (user_id, device_token, platform, created_at, updated_at)
      VALUES (@userId::UUID, @token, @platform, NOW(), NOW())
      ON CONFLICT (device_token)
      DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW()
      ''',
      substitutionValues: {
        'userId': userId,
        'token': token,
        'platform': platform,
      },
    );
  }

  Future<bool> notifyInvite({
    required String recipientUserId,
    required String senderName,
    required String inviteId,
  }) async {
    return _sendToUser(
      userId: recipientUserId,
      title: 'Chat invite',
      body: '$senderName sent you a chat invite',
      data: {
        'type': 'invitationSent',
        'inviteId': inviteId,
      },
    );
  }

  Future<bool> notifyNewMessage({
    required String recipientUserId,
    required String chatId,
    required String senderName,
    required String body,
  }) async {
    final chatService = ChatService(connection);
    final isMuted = await chatService.isChatMuted(chatId, recipientUserId);
    if (isMuted) {
      return false;
    }

    return _sendToUser(
      userId: recipientUserId,
      title: senderName,
      body: body,
      data: {
        'type': 'messageCreated',
        'chatId': chatId,
      },
    );
  }

  Future<bool> _sendToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    final result = await connection.query(
      '''
      SELECT device_token
      FROM push_device_tokens
      WHERE user_id = @userId::UUID
      ORDER BY updated_at DESC
      ''',
      substitutionValues: {'userId': userId},
    );

    if (result.isEmpty) {
      return false;
    }

    final serverKey = Platform.environment['FCM_SERVER_KEY'];
    if (serverKey == null || serverKey.isEmpty) {
      print('[NotificationService] No FCM_SERVER_KEY configured; skipping remote push for user $userId');
      return false;
    }

    var sent = false;
    for (final row in result) {
      final deviceToken = row[0] as String?;
      if (deviceToken == null || deviceToken.isEmpty) {
        continue;
      }

      final response = await _httpClient.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Authorization': 'key=$serverKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': deviceToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
          'priority': 'high',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        sent = true;
      } else {
        print('[NotificationService] Push send failed for user $userId: ${response.statusCode} ${response.body}');
      }
    }

    return sent;
  }
}
