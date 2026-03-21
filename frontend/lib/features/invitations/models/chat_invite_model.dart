/// Frontend representation of a chat invitation
class ChatInviteModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String recipientId;
  final String? recipientName;
  final String? recipientAvatarUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const ChatInviteModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAvatarUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  factory ChatInviteModel.fromJson(Map<String, dynamic> json) {
    return ChatInviteModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatarUrl: json['senderAvatarUrl'] as String?,
      recipientId: json['recipientId'] as String,
      recipientName: json['recipientName'] as String?,
      recipientAvatarUrl: json['recipientAvatarUrl'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatarUrl': senderAvatarUrl,
    'recipientId': recipientId,
    'recipientName': recipientName,
    'recipientAvatarUrl': recipientAvatarUrl,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
}
