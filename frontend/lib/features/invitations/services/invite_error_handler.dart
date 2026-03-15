/// Error handling utilities for invitation operations
class InviteErrorHandler {
  /// Map API error codes to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error is HttpException) {
      return _handleHttpException(error);
    }
    
    return 'An unexpected error occurred. Please try again.';
  }

  static String _handleHttpException(HttpException error) {
    final statusCode = error.statusCode;
    final message = error.message;

    switch (statusCode) {
      case 400:
        // Validation errors from backend
        if (message.contains('self-invite') || message.contains('self invite')) {
          return 'You cannot send an invitation to yourself.';
        }
        if (message.contains('already chatting') || message.contains('existing chat')) {
          return 'You\'re already chatting with this user.';
        }
        if (message.contains('duplicate') || message.contains('already sent')) {
          return 'You\'ve already sent an invitation to this user.';
        }
        return 'Invalid request. Please check your input and try again.';

      case 401:
        return 'Session expired. Please log in again.';

      case 403:
        return 'You don\'t have permission to perform this action.';

      case 404:
        return 'Invitation or user not found.';

      case 409:
        return 'An invitation has already been sent to this user.';

      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';

      case 504:
        return 'Server timeout. Please check your connection and try again.';

      default:
        return message.isNotEmpty
            ? message
            : 'An error occurred. Please try again.';
    }
  }

  /// Log errors for debugging (non-production logging)
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    print('[$context] Error: $error');
    if (stackTrace != null) {
      print('[$context] Stack: $stackTrace');
    }
  }
}

/// Custom exception for HTTP errors
class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, {this.statusCode});

  @override
  String toString() => 'HttpException: $message (status: $statusCode)';
}
