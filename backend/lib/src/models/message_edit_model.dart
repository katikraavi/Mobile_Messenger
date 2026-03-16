import 'package:json_annotation/json_annotation.dart';

part 'message_edit_model.g.dart';

/// Represents a single edit in a message's edit history
/// 
/// Maintains an immutable, timestamped audit trail of message modifications
/// - Stores the previous content before each edit
/// - Content is always encrypted (matches message encryption)
/// - Preserves who made each edit and when
@JsonSerializable()
class MessageEdit {
  /// Unique identifier for this edit record
  final String id;
  
  /// UUID of the message being edited
  @JsonKey(name: 'message_id')
  final String messageId;
  
  /// Sequential edit number (1 = first edit, 2 = second edit, etc.)
  @JsonKey(name: 'edit_number')
  final int editNumber;
  
  /// Previous message content (encrypted) before this edit
  /// Format: Base64-encoded ChaCha20-Poly1305 encrypted plaintext
  @JsonKey(name: 'previous_content')
  final String previousContent;
  
  /// When this edit occurred
  @JsonKey(name: 'edited_at')
  final DateTime editedAt;
  
  /// UUID of user who performed the edit
  @JsonKey(name: 'edited_by')
  final String editedBy;

  MessageEdit({
    required this.id,
    required this.messageId,
    required this.editNumber,
    required this.previousContent,
    required this.editedAt,
    required this.editedBy,
  });

  /// JSON serialization factory
  factory MessageEdit.fromJson(Map<String, dynamic> json) => _$MessageEditFromJson(json);
  
  /// Convert to JSON
  Map<String, dynamic> toJson() => _$MessageEditToJson(this);

  /// Get display label for edit history
  /// Example: "Message edited" or "1st edit" for UI
  String get displayLabel => editNumber == 1 ? 'Message edited' : '${editNumber.toString().padLeft(2, '0')}th edit';

  @override
  String toString() => 'MessageEdit(id: $id, messageId: $messageId, '
      'editNumber: $editNumber, editedAt: ${editedAt.toIso8601String()}, '
      'editedBy: $editedBy)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageEdit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          messageId == other.messageId &&
          editNumber == other.editNumber &&
          previousContent == other.previousContent &&
          editedAt == other.editedAt &&
          editedBy == other.editedBy;

  @override
  int get hashCode =>
      id.hashCode ^
      messageId.hashCode ^
      editNumber.hashCode ^
      previousContent.hashCode ^
      editedAt.hashCode ^
      editedBy.hashCode;
}
