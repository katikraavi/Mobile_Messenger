// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      encryptedContent: json['encrypted_content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      decryptedContent: json['decrypted_content'] as String?,
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'id': instance.id,
      'chat_id': instance.chatId,
      'sender_id': instance.senderId,
      'encrypted_content': instance.encryptedContent,
      'created_at': instance.createdAt.toIso8601String(),
      'decrypted_content': instance.decryptedContent,
    };
