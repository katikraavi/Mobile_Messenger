import 'package:json_annotation/json_annotation.dart';

part 'chat_model.g.dart';

/// Represents a 1:1 conversation between two users
/// 
/// Each chat is between exactly two participants and can be archived independently
/// by each participant using boolean archive flags.
@JsonSerializable()
class Chat {
  final String id;
  
  /// UUID of the first participant
  @JsonKey(name: 'participant_1_id')
  final String participant1Id;
  
  /// UUID of the second participant
  @JsonKey(name: 'participant_2_id')
  final String participant2Id;
  
  /// Whether participant 1 has archived this chat (per-user setting)
  @JsonKey(name: 'is_participant_1_archived')
  final bool isParticipant1Archived;
  
  /// Whether participant 2 has archived this chat (per-user setting)
  @JsonKey(name: 'is_participant_2_archived')
  final bool isParticipant2Archived;
  
  /// Chat creation timestamp
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  /// Last update timestamp (used for sorting by recency)
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Chat({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    required this.isParticipant1Archived,
    required this.isParticipant2Archived,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSON serialization factory
  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
  
  /// Convert to JSON
  Map<String, dynamic> toJson() => _$ChatToJson(this);

  /// Get the other participant's ID for the current user
  /// 
  /// Example: If currentUserId is participant1Id, returns participant2Id
  /// Throws ArgumentError if currentUserId is not a participant in this chat
  String getOtherId(String currentUserId) {
    if (currentUserId == participant1Id) return participant2Id;
    if (currentUserId == participant2Id) return participant1Id;
    throw ArgumentError(
      'Current user $currentUserId is not a participant in this chat',
    );
  }

  /// Check if the current user has archived this chat
  /// 
  /// Returns false if user is not a participant
  bool isArchivedForUser(String userId) {
    if (userId == participant1Id) return isParticipant1Archived;
    if (userId == participant2Id) return isParticipant2Archived;
    return false;
  }

  /// Check if current user is a participant in this chat
  bool isParticipant(String userId) {
    return userId == participant1Id || userId == participant2Id;
  }

  /// Get the state of archive flag for a specific participant
  bool getArchiveStatus(String participantId) {
    if (participantId == participant1Id) return isParticipant1Archived;
    if (participantId == participant2Id) return isParticipant2Archived;
    throw ArgumentError('User $participantId is not a participant in this chat');
  }

  @override
  String toString() => 'Chat(id: $id, p1: $participant1Id, p2: $participant2Id, '
      'archived1: $isParticipant1Archived, archived2: $isParticipant2Archived)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chat &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          participant1Id == other.participant1Id &&
          participant2Id == other.participant2Id &&
          isParticipant1Archived == other.isParticipant1Archived &&
          isParticipant2Archived == other.isParticipant2Archived &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      participant1Id.hashCode ^
      participant2Id.hashCode ^
      isParticipant1Archived.hashCode ^
      isParticipant2Archived.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
