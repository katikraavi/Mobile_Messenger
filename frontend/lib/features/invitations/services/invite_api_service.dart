import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat_invite_model.dart';

/// API service for invite-related HTTP operations
class InviteApiService {
  final String _baseUrl;
  final String? _authToken;
  final http.Client _httpClient;

  InviteApiService({
    required String baseUrl,
    String? authToken,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl,
        _authToken = authToken,
        _httpClient = httpClient ?? http.Client();

  /// Send a new invitation to a user
  /// POST /api/invites/send
  /// 
  /// Returns: ChatInviteModel
  /// Throws: HttpException on error
  Future<ChatInviteModel> sendInvite(String recipientId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/invites/send'),
        headers: _headers,
        body: jsonEncode({'recipientId': recipientId}),
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseInvite(json);
      } else if (response.statusCode == 409) {
        throw HttpException('Pending invitation already exists (409)', response.statusCode);
      } else if (response.statusCode == 400) {
        throw HttpException('Validation error: ${response.body}', response.statusCode);
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else {
        throw HttpException('Failed to send invite: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch pending invitations for the current user
  /// GET /api/invites/pending
  /// 
  /// Returns: List<ChatInviteModel>
  /// Throws: HttpException on error
  Future<List<ChatInviteModel>> fetchPendingInvites() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/api/invites/pending'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json.map((item) => _parseInvite(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else {
        throw HttpException('Failed to fetch pending invites: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch sent invitations for the current user
  /// GET /api/invites/sent
  /// 
  /// Returns: List<ChatInviteModel>
  /// Throws: HttpException on error
  Future<List<ChatInviteModel>> fetchSentInvites() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/api/invites/sent'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json.map((item) => _parseInvite(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else {
        throw HttpException('Failed to fetch sent invites: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Accept an invitation
  /// POST /api/invites/{id}/accept
  /// 
  /// Returns: ChatInviteModel
  /// Throws: HttpException on error
  Future<ChatInviteModel> acceptInvite(String inviteId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/invites/$inviteId/accept'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseInvite(json);
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 404) {
        throw HttpException('Invitation not found', response.statusCode);
      } else {
        throw HttpException('Failed to accept invite: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Decline an invitation
  /// POST /api/invites/{id}/decline
  /// 
  /// Returns: ChatInviteModel
  /// Throws: HttpException on error
  Future<ChatInviteModel> declineInvite(String inviteId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/invites/$inviteId/decline'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseInvite(json);
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 404) {
        throw HttpException('Invitation not found', response.statusCode);
      } else {
        throw HttpException('Failed to decline invite: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get count of pending invites (for badge)
  /// GET /api/invites/pending/count
  /// 
  /// Returns: int
  /// Throws: HttpException on error
  Future<int> getPendingInviteCount() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/api/invites/pending/count'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as int;
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else {
        throw HttpException('Failed to get invite count: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Private helpers

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  ChatInviteModel _parseInvite(Map<String, dynamic> json) {
    return ChatInviteModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String? ?? json['sender_id'] as String,
      senderName: json['senderName'] as String? ?? json['username'] as String? ?? 'Unknown',
      senderAvatarUrl: json['senderAvatarUrl'] as String? ?? json['avatar_url'] as String?,
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? json['updated_at'] as String),
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
    );
  }
}

/// HTTP Exception for API errors
class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
