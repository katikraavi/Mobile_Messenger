/// TypingService manages real-time typing indicator state
/// 
/// Tracks which users are typing in which chats with automatic timeout.
/// Used by WebSocket handler to broadcast typing events.
class TypingService {
  /// In-memory state of active typists
  /// Key: "chatId:userId", Value: TypingState
  static final Map<String, TypingState> _activeTypists = {};

  /// Monitor task for cleaning up expired typing states (runs every second)
  static Future<void>? _cleanupTask;

  /// Initialize the service and start cleanup task
  static void initialize() {
    // Start cleanup task if not already running
    if (_cleanupTask == null) {
      _startCleanupTask();
    }
  }

  /// Start the background cleanup task
  static void _startCleanupTask() {
    _cleanupTask = Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 1));
      
      // Remove expired typing states
      final now = DateTime.now();
      _activeTypists.removeWhere((key, state) {
        final elapsed = now.difference(state.startedAt);
        return elapsed.inSeconds > 3; // 3-second timeout
      });
      
      return true; // Continue loop indefinitely
    });
  }

  /// Record user as typing in a chat
  /// 
  /// Parameters:
  /// - userId: UUID of user typing
  /// - chatId: UUID of chat where user is typing
  /// 
  /// Returns: true if state changed (new typist), false if already typing
  static bool startTyping(String userId, String chatId) {
    final key = '$chatId:$userId';
    final isNew = !_activeTypists.containsKey(key);
    
    _activeTypists[key] = TypingState(
      userId: userId,
      chatId: chatId,
      startedAt: DateTime.now(),
    );
    
    return isNew;
  }

  /// Record user as no longer typing in a chat
  /// 
  /// Parameters:
  /// - userId: UUID of user who stopped typing
  /// - chatId: UUID of chat
  /// 
  /// Returns: true if state changed (user was typing), false if not typing
  static bool stopTyping(String userId, String chatId) {
    final key = '$chatId:$userId';
    return _activeTypists.remove(key) != null;
  }

  /// Get list of users currently typing in a chat
  /// 
  /// Parameters:
  /// - chatId: UUID of chat
  /// 
  /// Returns: List of userIds currently typing (empty list if none)
  static List<String> getTypingUsers(String chatId) {
    return _activeTypists.values
        .where((state) => state.chatId == chatId)
        .map((state) => state.userId)
        .toList();
  }

  /// Get all active typing sessions (for debugging)
  static Map<String, TypingState> getAllActiveSessions() {
    return Map.unmodifiable(_activeTypists);
  }

  /// Clear all typing states (for cleanup/reset)
  static void clearAll() {
    _activeTypists.clear();
  }

  /// Shutdown the service and cancel cleanup task
  static void shutdown() {
    _activeTypists.clear();
    _cleanupTask = null;
  }
}

/// Represents a user's typing state in a chat
class TypingState {
  /// UUID of the user typing
  final String userId;
  
  /// UUID of the chat
  final String chatId;
  
  /// When typing started
  final DateTime startedAt;

  TypingState({
    required this.userId,
    required this.chatId,
    required this.startedAt,
  });

  /// Duration user has been typing
  Duration get elapsedTime => DateTime.now().difference(startedAt);

  /// Whether this typing state has expired (>3 seconds)
  bool get isExpired => elapsedTime.inSeconds > 3;

  @override
  String toString() => 'TypingState(userId: $userId, chatId: $chatId, '
      'elapsed: ${elapsedTime.inSeconds}s, expired: $isExpired)';
}
