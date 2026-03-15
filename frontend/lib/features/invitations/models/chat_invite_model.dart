import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_invite_model.freezed.dart';
part 'chat_invite_model.g.dart';

/// Frontend representation of a chat invitation
@freezed
class ChatInviteModel with _$ChatInviteModel {
  const factory ChatInviteModel({
    required String id,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String recipientId,
    required String status, // 'pending', 'accepted', 'declined'
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _ChatInviteModel;

  factory ChatInviteModel.fromJson(Map<String, dynamic> json) =>
      _$ChatInviteModelFromJson(json);
}
