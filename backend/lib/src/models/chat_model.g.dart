// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chat _$ChatFromJson(Map<String, dynamic> json) => Chat(
      id: json['id'] as String,
      participant1Id: json['participant_1_id'] as String,
      participant2Id: json['participant_2_id'] as String,
      isParticipant1Archived: json['is_participant_1_archived'] as bool? ?? false,
      isParticipant2Archived: json['is_participant_2_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ChatToJson(Chat instance) => <String, dynamic>{
      'id': instance.id,
      'participant_1_id': instance.participant1Id,
      'participant_2_id': instance.participant2Id,
      'is_participant_1_archived': instance.isParticipant1Archived,
      'is_participant_2_archived': instance.isParticipant2Archived,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
