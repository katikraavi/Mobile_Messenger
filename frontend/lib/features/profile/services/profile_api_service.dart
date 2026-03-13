import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/features/profile/models/user_profile.dart';

/// API service for profile-related HTTP requests
/// 
/// Handles communication with the backend for profile operations:
/// - Fetching profile data
/// - Updating profile information
/// - Uploading profile pictures
/// - Deleting profile pictures

class ProfileApiService {
  /// Base API URL for profile endpoints
  static const String baseUrl = '/api/profile';

  /// Fetches user profile data from backend [T044]
  /// 
  /// Arguments:
  ///   - userId: User ID to fetch profile for
  /// 
  /// Returns: [UserProfile] object
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `GET /api/profile/:userId`
  /// Status: 200 = success, 401 = unauthorized, 404 = not found, 500 = server error
  Future<UserProfile> fetchProfile(String userId) async {
    try {
      // TODO: Implement HTTP GET request to fetch profile
      // For now, return mock data for development
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock profile data for testing
      return UserProfile(
        userId: userId,
        username: 'john_doe',
        profilePictureUrl: null, // Will load default avatar
        aboutMe: 'Software engineer & coffee enthusiast',
        isPrivateProfile: false,
        isDefaultProfilePicture: true,
        updatedAt: DateTime.now(),
      );
      
      /* Real implementation would look like:
      final response = await http.get(
        Uri.parse('$baseUrl/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw HttpException('User profile not found (404)');
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401)');
      } else {
        throw HttpException('Failed to fetch profile: ${response.statusCode}');
      }
      */
    } catch (e) {
      print('[ProfileApiService] Error fetching profile: $e');
      rethrow;
    }
  }

  /// Updates user profile information (username, bio, privacy setting) [T063]
  /// 
  /// Arguments:
  ///   - username: New username (3-32 characters)
  ///   - bio: New bio/about me text (0-500 characters)
  ///   - isPrivateProfile: Privacy setting (true = private, false = public)
  /// 
  /// Returns: Updated [UserProfile] object
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `PUT /api/profile`
  /// Status: 200 = success, 400 = validation error, 401 = unauthorized, 500 = server error
  Future<UserProfile> updateProfile({
    required String username,
    required String bio,
    required bool isPrivateProfile,
  }) async {
    try {
      // TODO: Replace with real HTTP PUT request when backend is ready
      // For now, simulate API call with delay
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Return updated profile with new values
      return UserProfile(
        userId: 'current_user', // Would come from auth context in real impl
        username: username,
        profilePictureUrl: null, // Unchanged
        aboutMe: bio,
        isPrivateProfile: isPrivateProfile,
        isDefaultProfilePicture: true, // Unchanged
        updatedAt: DateTime.now(),
      );
      
      /* Real implementation would look like:
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'aboutMe': bio,
          'isPrivateProfile': isPrivateProfile,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 400) {
        throw HttpException('Validation error: ${response.body}');
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401)');
      } else {
        throw HttpException('Failed to update profile: ${response.statusCode}');
      }
      */
    } catch (e) {
      print('[ProfileApiService] Error updating profile: $e');
      rethrow;
    }
  }

  /// Uploads a profile picture image
  /// 
  /// Arguments:
  ///   - imageFile: Image file to upload (must be JPEG or PNG, ≤5MB)
  /// 
  /// Returns: Updated [UserProfile] object with new profilePictureUrl
  /// 
  /// Throws: May throw HttpException, FormatException, or FileException on error
  /// 
  /// HTTP: `POST /api/profile/picture` (multipart/form-data)
  /// Status: 200 = success, 400 = validation error, 401 = unauthorized, 413 = file too large, 500 = server error
  Future<UserProfile> uploadImage(File imageFile) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/picture'),
      );

      // Add the image file to the request
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last,
      );
      
      request.files.add(multipartFile);

      // Send the request
      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw HttpException('Upload timeout after 60 seconds');
        },
      );

      // Read response body
      final responseBody = await response.stream.bytesToString();

      // Handle response based on status code
      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(responseBody);
          return UserProfile.fromJson(jsonBody);
        } catch (e) {
          throw FormatException(
            'Failed to parse profile response: $e',
            responseBody,
          );
        }
      } else if (response.statusCode == 400) {
        // Validation error (format, size, dimensions)
        throw HttpException(
          'Validation error: ${response.statusCode}. ${responseBody.isNotEmpty ? responseBody : 'Invalid image format or size'}',
        );
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401) - Please log in again');
      } else if (response.statusCode == 413) {
        throw HttpException('File too large (413) - Image must be smaller than 5MB');
      } else if (response.statusCode == 500) {
        throw HttpException(
          'Server error (500) - Unable to process image. Please try again.',
        );
      } else {
        throw HttpException(
          'Failed to upload image: HTTP ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      print('[ProfileApiService] Error uploading image: $e');
      rethrow;
    }
  }

  /// Deletes the profile picture (reverts to default avatar)
  /// 
  /// Returns: Updated [UserProfile] object (profilePictureUrl = null)
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `DELETE /api/profile/picture`
  /// Status: 200 = success, 401 = unauthorized, 404 = no picture to delete, 500 = server error
  Future<UserProfile> deleteImage() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/picture'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      // Read response body
      final responseBody = response.body;

      // Handle response based on status code
      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(responseBody);
          return UserProfile.fromJson(jsonBody);
        } catch (e) {
          throw FormatException(
            'Failed to parse profile response: $e',
            responseBody,
          );
        }
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401) - Please log in again');
      } else if (response.statusCode == 404) {
        throw HttpException('No picture to delete (404)');
      } else if (response.statusCode == 500) {
        throw HttpException(
          'Server error (500) - Unable to delete image. Please try again.',
        );
      } else {
        throw HttpException(
          'Failed to delete image: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[ProfileApiService] Error deleting image: $e');
      rethrow;
    }
  }
}
