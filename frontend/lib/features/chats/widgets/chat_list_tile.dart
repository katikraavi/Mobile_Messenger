import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'user_avatar_widget.dart';

/// Widget for displaying a single chat in the chat list
/// 
/// Shows:
/// - Participant name/avatar (placeholder)
/// - Last message preview (first 60 chars)
/// - Timestamp of last message
/// - Unread indicator (if needed - can be added later)
class ChatListTile extends StatelessWidget {
  /// The chat to display
  final Chat chat;

  /// The other participant's username (fetched separately)
  final String otherUserName;

  /// The last message in this chat (if any)
  final Message? lastMessage;

  /// The current user's ID (to determine which participant is "other")
  final String currentUserId;

  /// Callback when tile is tapped
  final VoidCallback onTap;

  /// Optional callback for swipe-to-archive (can be added later)
  final VoidCallback? onSwipeArchive;

  const ChatListTile({
    Key? key,
    required this.chat,
    required this.otherUserName,
    required this.currentUserId,
    required this.onTap,
    this.lastMessage,
    this.onSwipeArchive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // Leading: Avatar placeholder (can be replaced with actual profile image)
      leading: UserAvatarWidget(
        imageUrl: null,
        radius: 24,
        username: otherUserName,
      ),

      // Title: Other participant's name
      title: Text(
        otherUserName,
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
              lastMessage != null
                ? _getMessagePreview(lastMessage!)
                : 'No messages yet',
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

      // Tap handler
      onTap: onTap,

      // Visual feedback
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      
      // Divider
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
    );
  }

  /// Get a preview of the last message for display
  /// 
  /// Shows sender + message preview (first 50 chars)
  /// Example: "Alice: Hey, how are you..."
  String _getMessagePreview(Message message) {
    final senderPrefix = message.sentByUser(currentUserId) ? 'You: ' : '$otherUserName: ';
    final messageContent = message.isDecrypted 
      ? message.decryptedContent ?? '[Encrypted]'
      : '[Encrypted message]';

    // Truncate to 50 characters
    final truncated = messageContent.length > 50
      ? '${messageContent.substring(0, 50)}...'
      : messageContent;

    return '$senderPrefix$truncated';
  }
}
