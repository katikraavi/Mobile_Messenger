import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart' as img;

/// Media File Model
class PickedMediaFile {
  final String name;
  final String path;
  final Uint8List bytes;
  final String mimeType;
  final int sizeBytes;

  PickedMediaFile({
    required this.name,
    required this.path,
    required this.bytes,
    required this.mimeType,
    required this.sizeBytes,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isValid => sizeBytes > 0 && sizeBytes <= 20971520; // 20MB
}

/// Media Picker Service (T073)
/// 
/// Handles selecting images and videos from device
class MediaPickerService {
  static const int maxFileSize = 20971520; // 20MB in bytes
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
  ];

  static final _picker = img.ImagePicker();

  /// Pick an image from device
  /// 
  /// Returns: PickedMediaFile or null if cancelled
  static Future<PickedMediaFile?> pickImage() async {
    try {
      final image = await _picker.pickImage(source: img.ImageSource.gallery);
      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final fileName = image.name;

      // Determine MIME type from extension
      final mimeType = _getMimeTypeFromName(fileName);

      if (!allowedMimeTypes.contains(mimeType)) {
        throw Exception('Image type not supported: $mimeType');
      }

      if (bytes.length > maxFileSize) {
        throw Exception(
          'Image too large: ${bytes.length ~/ 1048576}MB (max 20MB)',
        );
      }

      return PickedMediaFile(
        name: fileName,
        path: image.path,
        bytes: bytes,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      print('[MediaPickerService] ❌ Error picking image: $e');
      rethrow;
    }
  }

  /// Pick a video from device
  /// 
  /// Returns: PickedMediaFile or null if cancelled
  static Future<PickedMediaFile?> pickVideo() async {
    try {
      final video = await _picker.pickVideo(source: img.ImageSource.gallery);
      if (video == null) return null;

      final bytes = await video.readAsBytes();
      final fileName = video.name;

      // Determine MIME type from extension
      final mimeType = _getMimeTypeFromName(fileName);

      if (!allowedMimeTypes.contains(mimeType)) {
        throw Exception('Video type not supported: $mimeType');
      }

      if (bytes.length > maxFileSize) {
        throw Exception(
          'Video too large: ${bytes.length ~/ 1048576}MB (max 20MB)',
        );
      }

      return PickedMediaFile(
        name: fileName,
        path: video.path,
        bytes: bytes,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      print('[MediaPickerService] ❌ Error picking video: $e');
      rethrow;
    }
  }

  /// Pick either image or video
  static Future<PickedMediaFile?> pickMedia() async {
    try {
      final result = await _picker.pickImage(source: img.ImageSource.gallery);
      if (result == null) return null;

      final bytes = await result.readAsBytes();
      final fileName = result.name;
      final mimeType = _getMimeTypeFromName(fileName);

      if (!allowedMimeTypes.contains(mimeType)) {
        throw Exception('Media type not supported: $mimeType');
      }

      if (bytes.length > maxFileSize) {
        throw Exception(
          'File too large: ${bytes.length ~/ 1048576}MB (max 20MB)',
        );
      }

      return PickedMediaFile(
        name: fileName,
        path: result.path,
        bytes: bytes,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      print('[MediaPickerService] ❌ Error picking media: $e');
      rethrow;
    }
  }

  /// Get MIME type from file name
  static String _getMimeTypeFromName(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    final mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }
}
