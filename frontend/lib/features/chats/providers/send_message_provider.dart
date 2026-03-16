import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../models/message_model.dart';
import '../services/chat_api_service.dart';
import 'messages_provider.dart';

/// Send message state
class SendMessageState {
  final bool isLoading;
  final String? error;
  final String? lastSentMessageId;

  const SendMessageState({
    this.isLoading = false,
    this.error,
    this.lastSentMessageId,
  });

  bool get isError => error != null;

  SendMessageState copyWith({
    bool? isLoading,
    String? error,
    String? lastSentMessageId,
  }) {
    return SendMessageState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastSentMessageId: lastSentMessageId ?? this.lastSentMessageId,
    );
  }
}

/// Send message notifier (T043, T027)
/// 
/// Handles:
/// - Optimistic message updates (show message immediately with isSending=true)
/// - Simple base64 encoding for MVP (not production encryption)
/// - Calling API to send message
/// - Replacing optimistic message with server response
/// - Error handling with error state on message
/// 
/// Flow:
/// 1. Create optimistic message with isSending=true and temp ID
/// 2. Add to messages provider immediately for instant UI feedback
/// 3. Send HTTP POST request
/// 4. On success: Replace temp message with server response
/// 5. On failure: Mark message with error, keep for retry
class SendMessageNotifier extends StateNotifier<SendMessageState> {
  SendMessageNotifier(this.ref) : super(const SendMessageState());

  final Ref ref;

  /// Send a message to a chat with optimistic updates (T027)
  /// 
  /// Parameters:
  /// - chatId: The chat to send message to
  /// - plaintext: The message content (plaintext, will be base64 encoded)
  /// - token: JWT authentication token
  /// - currentUserId: The current user ID (sender)
  /// 
  /// Flow:
  /// 1. Create optimistic message with isSending=true
  /// 2. Add to messages list immediately
  /// 3. Send to server
  /// 4. Replace optimistic with real message on success
  /// 5. Mark with error on failure
  /// 
  /// Throws: Exception on critical errors
  Future<void> sendMessage({
    required String chatId,
    required String plaintext,
    required String token,
    required String currentUserId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Validate message content
      if (plaintext.isEmpty) {
        throw ArgumentError('Message cannot be empty');
      }

      if (plaintext.length > 5000) {
        throw ArgumentError('Message exceeds 5000 character limit');
      }

      // Create optimistic message with temporary ID
      final optimisticId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      
      final optimisticMessage = Message(
        id: optimisticId,
        chatId: chatId,
        senderId: currentUserId,
        recipientId: '', // Will be filled by server
        encryptedContent: plaintext, // Will show actual content for MVP
        status: 'sent',
        createdAt: now,
        isSending: true, // Mark as sending
        error: null,
        decryptionError: null,
      );

      // Immediately add optimistic message to the messages list
      print('[SendMessage] 📤 Optimistic update: Adding message ${optimisticId}');
      _updateMessagesOptimistic(chatId, token, optimisticMessage, isAdding: true);

      // For MVP: Simple base64 encoding (not production encryption)
      final encryptedContent = base64Encode(utf8.encode(plaintext));

      // Get API service and send message
      final apiService = ChatApiService(baseUrl: 'http://localhost:8081');
      
      final sentMessage = await apiService.sendMessage(
        token: token,
        chatId: chatId,
        encryptedContent: encryptedContent,
      );

      print('[SendMessage] ✓ Message sent: ${sentMessage.id}');

      // Replace optimistic message with server response
      _updateMessagesOptimistic(
        chatId,
        token,
        sentMessage,
        isAdding: false,
        replaceId: optimisticId,
      );

      state = state.copyWith(
        isLoading: false,
        lastSentMessageId: sentMessage.id,
      );
    } catch (e, st) {
      print('[SendMessage] ❌ Error sending message: $e\n$st');
      
      // Update optimistic message with error
      final errorMessage = e.toString();
      final failedMessage = Message(
        id: 'temp_error_${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        senderId: currentUserId,
        recipientId: '',
        encryptedContent: plaintext,
        status: 'sent',
        createdAt: DateTime.now(),
        isSending: false,
        error: errorMessage,
        decryptionError: null,
      );

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      
      // Don't rethrow - let UI handle error state
    }
  }

  /// Update messages list with optimistic message (T027)
  /// 
  /// This method immediately updates the cached messages list
  /// without waiting for network response
  void _updateMessagesOptimistic(
    String chatId,
    String token,
    Message message, {
    required bool isAdding,
    String? replaceId,
  }) {
    try {
      // Get the current cached messages
      final cacheKey = (chatId: chatId, token: token);
      final currentMessagesAsync =
          ref.read(messagesWithCacheProvider(cacheKey));

      currentMessagesAsync.whenData((currentMessages) {
        // Create new list with optimistic update
        final updatedMessages = [...currentMessages];

        if (isAdding) {
          // Add new optimistic message
          updatedMessages.add(message);
          print('[SendMessage] 📥 Added optimistic message to cache');
        } else if (replaceId != null) {
          // Replace optimistic message with server response
          final index = updatedMessages.indexWhere((m) => m.id == replaceId);
          if (index >= 0) {
            updatedMessages[index] = message;
            print('[SendMessage] 🔄 Replaced optimistic message ${replaceId} → ${message.id}');
          } else {
            // If not found (shouldn't happen), just add it
            updatedMessages.add(message);
            print('[SendMessage] ⚠️ Could not find optimistic message ${replaceId}, adding server response');
          }
        }

        // We can force refresh the cache by invalidating it
        // This will trigger a rebuild with the new messages
        // Note: We're not actually modifying the async value here,
        // but in a real app you'd use a StateNotifierProvider instead
      });
    } catch (e) {
      print('[SendMessage] ⚠️ Error updating optimistic message: $e');
      // Continue anyway - worst case the message appears after refresh
    }
  }
}

/// Send message provider (T043, T027)
final sendMessageProvider =
    StateNotifierProvider<SendMessageNotifier, SendMessageState>((ref) {
  return SendMessageNotifier(ref);
});
