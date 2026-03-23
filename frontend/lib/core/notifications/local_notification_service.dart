import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _linuxNotificationsUnavailable = false;

  Future<void> initialize({
    required void Function(Map<String, dynamic> payload) onPayloadTap,
  }) async {
    if (_initialized) {
      return;
    }

    const settings = InitializationSettings(
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }
        onPayloadTap(jsonDecode(payload) as Map<String, dynamic>);
      },
    );

    _initialized = true;
  }

  Future<void> showMessageNotification({
    required String chatId,
    required String title,
    required String body,
  }) async {
    await _safeShow(
      id: chatId.hashCode,
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'chat_message',
        'chatId': chatId,
      }),
    );
  }

  Future<void> showInviteNotification({
    required String inviteId,
    required String title,
    required String body,
  }) async {
    await _safeShow(
      id: inviteId.hashCode,
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'chat_invite',
        'inviteId': inviteId,
      }),
    );
  }

  Future<void> _safeShow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) {
      return;
    }

    if (Platform.isLinux && _linuxNotificationsUnavailable) {
      return;
    }

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          linux: LinuxNotificationDetails(),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      final errorText = e.toString();
      final isLinuxNotificationServiceMissing = Platform.isLinux &&
          (errorText.contains('org.freedesktop.DBus.Error.ServiceUnknown') ||
              errorText.contains('org.freedesktop.Notifications'));

      if (isLinuxNotificationServiceMissing) {
        _linuxNotificationsUnavailable = true;
        print(
          '[LocalNotificationService] Notifications unavailable on Linux (no org.freedesktop.Notifications service).',
        );
        return;
      }

      // Do not crash message/invite flows for notification failures.
      print('[LocalNotificationService] Notification error: $e');
    }
  }
}
