import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../providers/user_profile_provider.dart';
import '../providers/active_chats_provider.dart';
import '../providers/archived_chats_provider.dart';
import '../services/chat_api_service.dart';
import '../screens/chat_detail_screen.dart';

/// Consumer widget for displaying a single chat in the chat list
/// 
/// This widget fetches the other user's profile information and displays it
class ChatListTileConsumer extends ConsumerWidget {
  /// The chat to display
  final Chat chat;

  /// The other participant's user ID
  final String otherUserId;

  /// The last message in this chat (if any)
  final Message? lastMessage;

  /// The current user's ID
  final String currentUserId;

  /// Auth token for API calls
  final String token;

  const ChatListTileConsumer({
    Key? key,
    required this.chat,
    required this.otherUserId,
    required this.currentUserId,
    required this.token,
    this.lastMessage,
  }) : super(key: key);

  /// Get a preview of the last message for display
  String _getMessagePreview(Message message) {
    final content = message.decryptedContent ?? '[Encrypted message]';
    return content.length > 50 ? '${content.substring(0, 50)}...' : content;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch the other user's profile
    final userProfileAsync = ref.watch(userProfileProvider((otherUserId, token)));

    return userProfileAsync.when(
      loading: () => ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: const Text('Loading...'),
        subtitle: const Text('Fetching profile...'),
      ),
      error: (error, st) => ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.red[100],
          child: Icon(Icons.error, color: Colors.red[400]),
        ),
        title: const Text('Error loading profile'),
        subtitle: const Text('Tap to retry'),
        onTap: () {
          ref.refresh(userProfileProvider((otherUserId, token)));
        },
      ),
      data: (userProfile) {
        // Display the chat tile with fetched user info
        return ListTile(
          // Leading: Avatar with profile picture or default image
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: userProfile.profilePictureUrl != null
                ? NetworkImage(userProfile.profilePictureUrl!)
                : const AssetImage('assets/images/profile/defailtProfilePic.jpg'),
            backgroundColor: Colors.grey[300],
          ),

          // Title: Other participant's username
          title: Text(
            userProfile.username,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),

          // Subtitle: Last message preview + timestamp
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Last message preview (truncated)
              Expanded(
                child: Text(
                  lastMessage != null ? _getMessagePreview(lastMessage!) : 'No messages yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Timestamp
              if (lastMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    lastMessage!.getDisplayTime(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
            ],
          ),

          // Tap handler - navigate to chat detail screen
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  chatId: chat.id,
                  otherUserId: otherUserId,
                  otherUserName: userProfile.username,
                  otherUserAvatarUrl: userProfile.profilePictureUrl,
                ),
              ),
            );
          },

          // Visual feedback
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          // Trailing menu button with archive option
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'archive') {
                try {
                  const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8081');
                  final chatService = ChatApiService(baseUrl: baseUrl);
                  
                  await chatService.archiveChat(
                    token: token,
                    chatId: chat.id,
                  );
                  
                  // Refresh both active and archived chats
                  ref.refresh(activeChatListProvider(token));
                  ref.refresh(archivedChatsProvider(token));
                  
                  // Show feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Chat archived')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to archive: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Archive'),
                    ],
                  ),
                ),
              ];
            },
            icon: Icon(
              Icons.more_vert,
              color: Colors.grey[400],
            ),
          ),
        );
      },
    );
  }
}
