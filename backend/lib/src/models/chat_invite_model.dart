/// Data model for invitations in the Invitation Send/Accept/Reject/Cancel feature
library;

/// Represents a single invitation for initiating a conversation
class ChatInviteModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String receiverId;
  final String recipientName;
  final String? recipientAvatarUrl;
  final String status; // 'pending', 'accepted', 'rejected', 'canceled'
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? canceledAt;

  ChatInviteModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.receiverId,
    required this.recipientName,
    this.recipientAvatarUrl,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.canceledAt,
  });

  /// Convert model to JSON for API responses
  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatarUrl': senderAvatarUrl,
    'recipientId': receiverId,
    'recipientName': recipientName,
    'recipientAvatarUrl': recipientAvatarUrl,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
    'canceledAt': canceledAt?.toIso8601String(),
  };

  /// Create model from JSON
  factory ChatInviteModel.fromJson(Map<String, dynamic> json) {
    return ChatInviteModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatarUrl: json['senderAvatarUrl'] as String?,
      receiverId: json['recipientId'] as String,
      recipientName: json['recipientName'] as String,
      recipientAvatarUrl: json['recipientAvatarUrl'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      respondedAt: json['respondedAt'] != null 
        ? DateTime.parse(json['respondedAt'] as String)
        : null,
      canceledAt: json['canceledAt'] != null
        ? DateTime.parse(json['canceledAt'] as String)
        : null,
    );
  }

  /// Convert database row to invitation DTO
  factory ChatInviteModel.fromDatabaseRow(Map<String, dynamic> row) {
    return ChatInviteModel(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String? ?? row['senderName'] as String,
      senderAvatarUrl: row['sender_avatar'] as String? ?? row['senderAvatarUrl'] as String?,
      receiverId: row['receiver_id'] as String,
      recipientName: row['receiver_name'] as String? ?? row['recipientName'] as String,
      recipientAvatarUrl: row['receiver_avatar'] as String? ?? row['recipientAvatarUrl'] as String?,
      status: row['status'] as String,
      createdAt: row['created_at'] as DateTime,
      respondedAt: row['responded_at'] as DateTime?,
      canceledAt: row['canceled_at'] as DateTime?,
    );
  }

  @override
  String toString() => 'ChatInviteModel(id=$id, sender=$senderName, recipient=$recipientName, status=$status)';

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ChatInviteModel &&
    runtimeType == other.runtimeType &&
    id == other.id;

  @override
  int get hashCode => id.hashCode;
}
