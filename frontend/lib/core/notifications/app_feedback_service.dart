import 'package:flutter/material.dart';

enum AppFeedbackLevel { info, warning, error }

class AppFeedbackService {
  AppFeedbackService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static String? _lastMessage;
  static DateTime? _lastShownAt;

  static void showInfo(String message) {
    _show(message, level: AppFeedbackLevel.info);
  }

  static void showWarning(String message) {
    _show(message, level: AppFeedbackLevel.warning);
  }

  static void showError(String message) {
    _show(message, level: AppFeedbackLevel.error);
  }

  static void _show(
    String message, {
    required AppFeedbackLevel level,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null || message.trim().isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 4)) {
      return;
    }

    _lastMessage = message;
    _lastShownAt = now;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: switch (level) {
          AppFeedbackLevel.info => Colors.blueGrey.shade700,
          AppFeedbackLevel.warning => Colors.orange.shade800,
          AppFeedbackLevel.error => Colors.red.shade700,
        },
        duration: Duration(
          seconds: level == AppFeedbackLevel.error ? 6 : 4,
        ),
      ),
    );
  }
}