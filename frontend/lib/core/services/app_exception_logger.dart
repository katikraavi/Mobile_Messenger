import 'package:flutter/foundation.dart';

class AppExceptionLogger {
  AppExceptionLogger._();

  static void log(
    Object error, {
    StackTrace? stackTrace,
    required String context,
    bool fatal = false,
  }) {
    final severity = fatal ? 'FATAL' : 'ERROR';
    debugPrint('[AppException][$severity][$context] $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}