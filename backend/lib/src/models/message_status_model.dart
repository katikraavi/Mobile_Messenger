import 'package:json_annotation/json_annotation.dart';

part 'message_status_model.g.dart';

/// Tracks the delivery and read status of a message per recipient
/// 
/// Used in 1-to-1 messaging to track:
/// - When message was delivered to recipient
/// - When message was read by recipient
/// - Current status progression: sent → delivered → read
@JsonSerializable()
class MessageStatus {
  /// Unique identifier for this status record
  final String id;
  
  /// UUID of the message this status tracks
  @JsonKey(name: 'message_id')
  final String messageId;
  
  /// UUID of the recipient user
  @JsonKey(name: 'recipient_id')
  final String recipientId;
  
  /// Current status: sent, delivered, or read
  /// - 'sent': Message delivered to server
  /// - 'delivered': Message received by recipient device
  /// - 'read': Message opened/read by recipient
  @JsonKey(name: 'status')
  final String status;
  
  /// When status changed to 'delivered' (null if not yet delivered)
  @JsonKey(name: 'delivered_at')
  final DateTime? deliveredAt;
  
  /// When status changed to 'read' (null if not yet read)
  @JsonKey(name: 'read_at')
  final DateTime? readAt;
  
  /// Last update timestamp
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  MessageStatus({
    required this.id,
    required this.messageId,
    required this.recipientId,
    required this.status,
    required this.updatedAt,
    this.deliveredAt,
    this.readAt,
  });

  /// JSON serialization factory
  factory MessageStatus.fromJson(Map<String, dynamic> json) => _$MessageStatusFromJson(json);
  
  /// Convert to JSON
  Map<String, dynamic> toJson() => _$MessageStatusToJson(this);

  /// Check if message has been delivered
  bool get isDelivered => status == 'delivered' || status == 'read';
  
  /// Check if message has been read
  bool get isRead => status == 'read';
  
  /// Get progress percentage for UI representation
  /// 0% = sent, 50% = delivered, 100% = read
  int get progressPercentage {
    switch (status) {
      case 'sent':
        return 0;
      case 'delivered':
        return 50;
      case 'read':
        return 100;
      default:
        return 0;
    }
  }

  @override
  String toString() => 'MessageStatus(id: $id, messageId: $messageId, '
      'recipient: $recipientId, status: $status, updated: ${updatedAt.toIso8601String()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageStatus &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          messageId == other.messageId &&
          recipientId == other.recipientId &&
          status == other.status &&
          deliveredAt == other.deliveredAt &&
          readAt == other.readAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      messageId.hashCode ^
      recipientId.hashCode ^
      status.hashCode ^
      deliveredAt.hashCode ^
      readAt.hashCode ^
      updatedAt.hashCode;
}
