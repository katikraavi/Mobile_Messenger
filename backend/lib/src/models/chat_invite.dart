import 'package:serverpod/serverpod.dart';

/// Represents a formal invitation from one user to another to initiate a 1-to-1 conversation
@freezed
class ChatInvite with _$ChatInvite {
  factory ChatInvite({
    required String id,
    required String senderId,
    required String recipientId,
    required String status, // 'pending', 'accepted', 'declined'
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _ChatInvite;

  factory ChatInvite.fromJson(Map<String, dynamic> json) =>
      _$ChatInviteFromJson(json);
}
