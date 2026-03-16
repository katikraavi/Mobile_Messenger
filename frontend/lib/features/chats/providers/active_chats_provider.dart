import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import 'chats_provider.dart';

/// Provider for active (unarchived) chats
/// 
/// For MVP: Requires passing JWT token
final activeChatListProvider = FutureProvider.family<List<Chat>, String>((ref, token) async {
  // Get all chats
  final chats = await ref.watch(chatsProvider(token).future);
  return chats;
});

/// Provider for archived chats
final archivedChatListProvider = FutureProvider.family<List<Chat>, String>((ref, token) async {
  // Get all chats
  final chats = await ref.watch(chatsProvider(token).future);
  // Filter to archived (would need to know current user ID from UI)
  return [];
});
