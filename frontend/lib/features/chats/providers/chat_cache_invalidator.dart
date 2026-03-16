import 'package:flutter_riverpod/flutter_riverpod.dart';

/// StateProvider for cache invalidation counter
/// 
/// Used to force refresh of chat data when needed (e.g., after login, after sending a message).
/// Incrementing this counter will cause all dependent providers to update.
/// 
/// The counter's value is meaningless - only changes matter. Each increment triggers
/// any dependent providers to recompute.
/// 
/// Usage - Force refresh:
/// ```dart
/// ref.read(chatsCacheInvalidatorProvider.notifier).state++;
/// ```
/// 
/// Usage - In dependent provider:
/// ```dart
/// final chats = FutureProvider((ref) async {
///   ref.watch(chatsCacheInvalidatorProvider); // Dependencies on invalidation counter
///   // ... fetch data
/// });
/// ```
final chatsCacheInvalidatorProvider = StateProvider<int>((ref) {
  // Initial value: 0
  // Increment whenever cache should be refreshed
  return 0;
});

/// Provider for invalidating messages cache for a specific chat
/// 
/// Allows granular cache invalidation per chat (when new messages arrive, etc.)
/// 
/// Usage - Force refresh messages for a chat:
/// ```dart
/// ref.read(messagesCacheInvalidatorProvider('chat-123').notifier).state++;
/// ```
final messagesCacheInvalidatorProvider = StateProvider.family<int, String>((ref, chatId) {
  return 0;
});

/// Function to refresh all chat-related caches
/// 
/// Call this when:
/// - User logs in (re-fetch all chats)
/// - After archiving/unarchiving a chat
/// - After creating a new chat
/// - After significant UI action that may have stale data
/// 
/// Usage:
/// ```dart
/// invalidateChatsCaches(ref);
/// ```
void invalidateChatsCaches(WidgetRef ref) {
  ref.read(chatsCacheInvalidatorProvider.notifier).state++;
}

/// Function to refresh messages for a specific chat
/// 
/// Call this when:
/// - New messages received (WebSocket event)
/// - User manually refreshes
/// - After sending a message
/// 
/// Usage:
/// ```dart
/// invalidateMessagesCache(ref, 'chat-123');
/// ```
void invalidateMessagesCache(WidgetRef ref, String chatId) {
  ref.read(messagesCacheInvalidatorProvider(chatId).notifier).state++;
}

/// Extension on WidgetRef for convenient cache invalidation
extension ChatCacheInvalidation on WidgetRef {
  /// Invalidate chats cache
  void invalidateChatsCache() {
    read(chatsCacheInvalidatorProvider.notifier).state++;
  }

  /// Invalidate messages cache for a specific chat
  void invalidateMessagesCache(String chatId) {
    read(messagesCacheInvalidatorProvider(chatId).notifier).state++;
  }
}
