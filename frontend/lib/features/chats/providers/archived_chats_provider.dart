import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../services/chat_api_service.dart';

/// Provider for archived chats list for the current user
/// 
/// This provider fetches all archived chats from the backend.
/// It's a family provider that takes the JWT token as parameter.
/// 
/// Usage:
/// ```dart
/// final archivedChats = ref.watch(archivedChatsProvider(token));
/// ```
final archivedChatsProvider = FutureProvider.family<List<Chat>, String>((ref, token) async {
  try {
    print('[ArchivedChatsProvider] 📡 Fetching archived chats with token: ${token.substring(0, 20)}...');
    
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8081');
    final chatService = ChatApiService(baseUrl: baseUrl);
    
    final chats = await chatService.fetchArchivedChats(token: token);
    
    print('[ArchivedChatsProvider] ✅ Fetched ${chats.length} archived chats');
    return chats;
  } catch (e) {
    print('[ArchivedChatsProvider] ❌ Error fetching archived chats: $e');
    rethrow;
  }
});
