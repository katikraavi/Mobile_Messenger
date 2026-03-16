import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'media_picker_service.dart';

/// Media Upload Service Model
class UploadedMedia {
  final String id;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String filePath;
  final String? originalName;
  final DateTime createdAt;

  UploadedMedia({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.filePath,
    this.originalName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'file_name': fileName,
    'mime_type': mimeType,
    'file_size_bytes': fileSizeBytes,
    'file_path': filePath,
    'original_name': originalName,
    'created_at': createdAt.toIso8601String(),
  };

  static UploadedMedia fromJson(Map<String, dynamic> json) => UploadedMedia(
    id: json['id'] as String,
    fileName: json['file_name'] as String,
    mimeType: json['mime_type'] as String,
    fileSizeBytes: json['file_size_bytes'] as int,
    filePath: json['file_path'] as String,
    originalName: json['original_name'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Media Upload Service (T074)
/// 
/// Handles uploading picked media files to the backend
class MediaUploadService {
  final http.Client _httpClient;
  final String _baseUrl;

  MediaUploadService({
    http.Client? httpClient,
    String? baseUrl,
  })
      : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? 'http://localhost:8081';

  /// Upload media file (T074)
  /// 
  /// Parameters:
  /// - pickedMedia: Media file picked from device
  /// - token: JWT authentication token
  /// 
  /// Returns: UploadedMedia with server metadata
  /// 
  /// Throws: Exception if upload fails
  Future<UploadedMedia> uploadMedia({
    required PickedMediaFile pickedMedia,
    required String token,
  }) async {
    try {
      // Validate before upload
      if (!pickedMedia.isValid) {
        throw Exception('Invalid media file');
      }

      print(
          '[MediaUploadService] 📤 Uploading ${pickedMedia.mimeType}: ${pickedMedia.sizeBytes ~/ 1024}KB');

      // For MVP, upload as raw bytes with headers (multipart would need http_parser)
      final url = Uri.parse('$_baseUrl/api/media/upload');

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
          'X-File-Type': pickedMedia.mimeType,
          'X-File-Name': pickedMedia.name,
        },
        body: pickedMedia.bytes,
      );

      if (response.statusCode == 201) {
        final mediaData = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadedMedia = UploadedMedia.fromJson(mediaData);
        print(
            '[MediaUploadService] ✅ Upload successful: ${uploadedMedia.id}');
        return uploadedMedia;
      } else if (response.statusCode == 413) {
        throw Exception('File too large (max 20MB)');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode >= 400) {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception('Upload failed: ${error['error']}');
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[MediaUploadService] ❌ Upload error: $e');
      rethrow;
    }
  }

  /// Attach uploaded media to message (T075)
  /// 
  /// Links an already-uploaded media file to a message
  /// 
  /// Parameters:
  /// - messageId: Message to attach media to
  /// - mediaId: ID of uploaded media file
  /// - token: JWT authentication token
  /// 
  /// Returns: Attachment metadata
  Future<Map<String, dynamic>> attachMediaToMessage({
    required String messageId,
    required String mediaId,
    required String token,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/messages/$messageId/attach-media');

      final response = await _httpClient.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'media_id': mediaId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        print('[MediaUploadService] ✓ Media attached to message: $messageId');
        return result;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: You can only attach to your own messages');
      } else if (response.statusCode == 404) {
        throw Exception('Message or media not found');
      } else {
        throw Exception('Failed to attach media: ${response.statusCode}');
      }
    } catch (e) {
      print('[MediaUploadService] ❌ Attach error: $e');
      rethrow;
    }
  }

  /// Download media file (T076)
  /// 
  /// Parameters:
  /// - mediaId: ID of media to download
  /// - token: JWT authentication token
  /// 
  /// Returns: File bytes
  Future<Uint8List> downloadMedia({
    required String mediaId,
    required String token,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/media/$mediaId/download');

      print('[MediaUploadService] 📥 Downloading media: $mediaId');

      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('[MediaUploadService] ✅ Download complete: $mediaId');
        return response.bodyBytes;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 404) {
        throw Exception('Media not found');
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[MediaUploadService] ❌ Download error: $e');
      rethrow;
    }
  }
}
