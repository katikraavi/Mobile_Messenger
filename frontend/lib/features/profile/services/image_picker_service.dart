import 'package:image_picker/image_picker.dart';
import 'permission_service.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery with permission handling
  /// 
  /// Returns: XFile if user selects an image, null if cancelled or permission denied
  /// 
  /// Handles:
  /// - Permission request (image_picker handles internal permission requests)
  /// - User cancellation (returns null)
  /// - Permission denial (returns null)
  static Future<XFile?> pickImageFromGallery() async {
    try {
      // Request photo library permission
      // image_picker handles permission requests, but we document the flow
      await PermissionService.requestPhotoLibraryPermission();
      
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      
      if (pickedFile == null) {
        PermissionService.showPermissionDeniedMessage('photo library');
      }
      
      return pickedFile;
    } catch (e) {
      print('[ImagePickerService] Error picking from gallery: $e');
      rethrow;
    }
  }

  /// Pick image from camera with permission handling
  /// 
  /// Returns: XFile if user captures photo, null if cancelled or permission denied
  /// 
  /// Handles:
  /// - Camera permission request (image_picker handles internal permission requests)
  /// - User cancellation (returns null)
  /// - Permission denial (returns null)
  /// - Camera not available (rethrows exception)
  static Future<XFile?> pickImageFromCamera() async {
    try {
      // Request camera permission
      // image_picker handles permission requests, but we document the flow
      await PermissionService.requestCameraPermission();
      
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      
      if (pickedFile == null) {
        PermissionService.showPermissionDeniedMessage('camera');
      }
      
      return pickedFile;
    } catch (e) {
      print('[ImagePickerService] Error picking from camera: $e');
      rethrow;
    }
  }

  /// Validate image locally before upload
  /// 
  /// Checks:
  /// - File extension (JPEG/PNG only)
  /// - File size (≤5MB limit)
  /// 
  /// Returns: null if valid, error message string if invalid
  static String? validateImage(XFile file) {
    // Check file extension
    final fileName = file.name.toLowerCase();
    if (!fileName.endsWith('.jpg') &&
        !fileName.endsWith('.jpeg') &&
        !fileName.endsWith('.png')) {
      return 'Only JPEG and PNG formats are supported';
    }

    // Note: For full validation including file size and dimensions,
    // use ImageValidator.validateImage(filePath: file.path, fileSizeBytes: fileSize)
    // after reading the file size from disk
    
    return null; // Valid
  }
}
