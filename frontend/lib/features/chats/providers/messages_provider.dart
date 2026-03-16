import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../services/chat_api_service.dart';
import './receive_messages_provider.dart';

/// Messages provider (T044, T036-T037)
/// 
/// Fetches messages for a specific chat with JWT token
/// Enhanced to reactively include messages received via WebSocket
final messagesProvider =
    FutureProvider.family<List<Message>, ({String chatId, String token})>(
        (ref, params) async {
  final token = params.token;
  final chatId = params.chatId;

  if (token.isEmpty) {
    throw Exception('User not authenticated');
  }

  // Get API service
  final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

  // Fetch messages for this chat
  try {
    final messages = await apiService.fetchMessages(
      token: token,
      chatId: chatId,
      limit: 50,
    );
    return messages;
  } catch (e) {
    print('[MessagesProvider] Error fetching messages: $e');
    rethrow;
  }
});

/// Messages cache invalidator for a specific chat
final messagesCacheInvalidatorProvider =
    StateProvider.family<int, String>((ref, chatId) => 0);

/// Messages provider with cache invalidation support (T036-T037)
/// 
/// Enhanced to reactively include messages received via WebSocket
/// and auto-update when new messages are received
final messagesWithCacheProvider =
    FutureProvider.family<List<Message>, ({String chatId, String token})>(
        (ref, params) async {
  final chatId = params.chatId;
  final token = params.token;

  // Watch the cache invalidator to trigger refreshes
  ref.watch(messagesCacheInvalidatorProvider(chatId));

  // Also watch for received messages via WebSocket (T037)
  final receivedMessage = ref.watch(receiveMessageStreamProvider);
  
  // When a message is received for this chat, refresh the messages
  receivedMessage.whenData((event) {
    if (event != null && event.chatId == chatId) {
      print('[MessagesWithCacheProvider] 📨 Received message for chat $chatId, refreshing...');
      // Increment cache invalidator to trigger refresh
      ref.read(messagesCacheInvalidatorProvider(chatId).notifier).state++;
    }
  });

  // Fetch messages
  final apiService = ChatApiService(baseUrl: 'http://localhost:8081');
  
  try {
    final messages = await apiService.fetchMessages(
      token: token,
      chatId: chatId,
      limit: 50,
    );
    
    print('[MessagesWithCacheProvider] ✓ Fetched ${messages.length} messages');
    return messages;
  } catch (e) {
    print('[MessagesWithCacheProvider] Error fetching messages: $e');
    rethrow;
  }
});

/// Edit message provider (T055, US4)
/// 
/// Allows editing an existing message with optimistic updates
final editMessageProvider = FutureProvider.family<Message, (String, String, String, String)>((ref, params) async {
  final chatId = params.$1;
  final messageId = params.$2;
  final newContent = params.$3;
  final token = params.$4;

  if (token.isEmpty) {
    throw Exception('User not authenticated');
  }

  final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

  try {
    print('[EditMessageProvider] 📝 Editing message $messageId with new content');
    
    final editedMessage = await apiService.editMessage(
      token: token,
      chatId: chatId,
      messageId: messageId,
      newEncryptedContent: newContent,
    );

    print('[EditMessageProvider] ✓ Message edited successfully');
    
    // Invalidate messages cache to refresh
    ref.invalidate(messagesWithCacheProvider((chatId: chatId, token: token)));
    
    return editedMessage;
  } catch (e) {
    print('[EditMessageProvider] ❌ Error editing message: $e');
    rethrow;
  }
});

/// Delete message provider
/// 
/// Deletes a message by ID and invalidates the messages cache
final deleteMessageProvider = FutureProvider.family<void, (String, String, String)>((ref, params) async {
  final chatId = params.$1;
  final messageId = params.$2;
  final token = params.$3;

  if (token.isEmpty) {
    throw Exception('User not authenticated');
  }

  final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

  try {
    print('[DeleteMessageProvider] 🗑️ Deleting message $messageId');
    
    await apiService.deleteMessage(
      token: token,
      chatId: chatId,
      messageId: messageId,
    );

    print('[DeleteMessageProvider] ✓ Message deleted successfully');
    
    // Invalidate messages cache to refresh
    ref.invalidate(messagesWithCacheProvider((chatId: chatId, token: token)));
  } catch (e) {
    print('[DeleteMessageProvider] ❌ Error deleting message: $e');
    rethrow;
  }
});
