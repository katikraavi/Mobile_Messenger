# Quickstart: User Profile System

**Last Updated**: 2026-03-11  
**Audience**: Backend and frontend developers implementing profile features  
**Time Needed**: 2-3 hours per layer (backend, frontend)

## Overview

This guide provides code templates and step-by-step instructions for implementing the profile system. Follow the layers in order: (1) database migrations, (2) backend services and endpoints, (3) frontend screens and state management.

---

## Prerequisites

- Existing backend (Spec 001-004) running in Docker
- Existing frontend (Flutter app with Riverpod state management)
- Postman or cURL for API testing
- Understanding of Shelf framework and Flutter development

---

## Part 1: Database Setup (Backend)

### Step 1.1: Create Migration Files

Create two new migration files in `backend/migrations/`:

**File: `backend/migrations/011_add_profile_fields_to_user.dart`**

```dart
import 'package:database/database.dart';

class Migration011 extends Migration {
  @override
  String get name => '011_add_profile_fields_to_user';

  @override
  Future<void> up(PostgresConnection connection) async {
    await connection.execute('''
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS about_me TEXT DEFAULT '';
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS is_default_profile_picture BOOLEAN DEFAULT true NOT NULL;
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS is_private_profile BOOLEAN DEFAULT false NOT NULL;
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS profile_updated_at TIMESTAMP WITH TIME ZONE;
    ''');
    
    await connection.execute('''
      CREATE INDEX IF NOT EXISTS idx_user_is_private_profile ON "user"(is_private_profile);
      CREATE INDEX IF NOT EXISTS idx_user_profile_updated_at ON "user"(profile_updated_at DESC);
    ''');
  }

  @override
  Future<void> down(PostgresConnection connection) async {
    await connection.execute('DROP INDEX IF EXISTS idx_user_profile_updated_at;');
    await connection.execute('DROP INDEX IF EXISTS idx_user_is_private_profile;');
    await connection.execute('''
      ALTER TABLE "user" DROP COLUMN IF EXISTS profile_picture_url;
      ALTER TABLE "user" DROP COLUMN IF EXISTS about_me;
      ALTER TABLE "user" DROP COLUMN IF EXISTS is_default_profile_picture;
      ALTER TABLE "user" DROP COLUMN IF EXISTS is_private_profile;
      ALTER TABLE "user" DROP COLUMN IF EXISTS profile_updated_at;
    ''');
  }
}
```

**File: `backend/migrations/012_create_profile_image_table.dart`**

```dart
import 'package:database/database.dart';

class Migration012 extends Migration {
  @override
  String get name => '012_create_profile_image_table';

  @override
  Future<void> up(PostgresConnection connection) async {
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS "profile_image" (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 5242880),
        original_format VARCHAR(10) NOT NULL CHECK (original_format IN ('jpeg', 'png')),
        stored_format VARCHAR(10) NOT NULL DEFAULT 'jpeg' CHECK (stored_format IN ('jpeg', 'png')),
        width_px INTEGER NOT NULL,
        height_px INTEGER NOT NULL,
        is_active BOOLEAN DEFAULT false NOT NULL,
        uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
        deleted_at TIMESTAMP WITH TIME ZONE,
        
        CONSTRAINT check_single_active UNIQUE (user_id, is_active) WHERE is_active = true,
        CONSTRAINT check_deletion_time CHECK (deleted_at IS NULL OR deleted_at >= uploaded_at)
      );

      CREATE INDEX idx_profile_image_user_id ON "profile_image"(user_id);
      CREATE INDEX idx_profile_image_is_active ON "profile_image"(is_active);
      CREATE INDEX idx_profile_image_uploaded_at ON "profile_image"(uploaded_at DESC);
      CREATE INDEX idx_profile_image_user_active ON "profile_image"(user_id, is_active) WHERE is_active = true;
    ''');
  }

  @override
  Future<void> down(PostgresConnection connection) async {
    await connection.execute('DROP TABLE IF EXISTS "profile_image" CASCADE;');
  }
}
```

### Step 1.2: Register Migrations

In `backend/lib/src/services/database_service.dart`, add the new migrations to the list:

```dart
List<Migration> getAllMigrations() => [
  // ... existing migrations ...
  Migration011(),
  Migration012(),
];
```

### Step 1.3: Run Migrations

Stop and restart the backend container to auto-run migrations:

```bash
docker-compose down
docker-compose up --build
```

Verify in logs: `[INFO] Migration 012 completed successfully`

---

## Part 2: Backend Implementation

### Step 2.1: Create Models

**File: `backend/lib/src/models/user_profile.dart`**

```dart
class UserProfile {
  final String id;
  final String email;
  final String username;
  final String? profilePictureUrl;
  final String aboutMe;
  final bool isDefaultProfilePicture;
  final bool isPrivateProfile;
  final DateTime? profileUpdatedAt;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.profilePictureUrl,
    this.aboutMe = '',
    this.isDefaultProfilePicture = true,
    this.isPrivateProfile = false,
    this.profileUpdatedAt,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    profilePictureUrl: json['profile_picture_url'] as String?,
    aboutMe: json['about_me'] as String? ?? '',
    isDefaultProfilePicture: json['is_default_profile_picture'] as bool? ?? true,
    isPrivateProfile: json['is_private_profile'] as bool? ?? false,
    profileUpdatedAt: json['profile_updated_at'] != null 
      ? DateTime.parse(json['profile_updated_at'] as String)
      : null,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'profilePictureUrl': profilePictureUrl,
    'aboutMe': aboutMe,
    'isDefaultProfilePicture': isDefaultProfilePicture,
    'isPrivateProfile': isPrivateProfile,
    'profileUpdatedAt': profileUpdatedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
```

**File: `backend/lib/src/models/profile_image.dart`**

```dart
class ProfileImage {
  final String id;
  final String userId;
  final String filePath;
  final int fileSizeBytes;
  final String originalFormat;
  final String storedFormat;
  final int widthPx;
  final int heightPx;
  final bool isActive;
  final DateTime uploadedAt;
  final DateTime? deletedAt;

  ProfileImage({
    required this.id,
    required this.userId,
    required this.filePath,
    required this.fileSizeBytes,
    required this.originalFormat,
    required this.storedFormat,
    required this.widthPx,
    required this.heightPx,
    required this.isActive,
    required this.uploadedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory ProfileImage.fromJson(Map<String, dynamic> json) => ProfileImage(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    filePath: json['file_path'] as String,
    fileSizeBytes: json['file_size_bytes'] as int,
    originalFormat: json['original_format'] as String,
    storedFormat: json['stored_format'] as String,
    widthPx: json['width_px'] as int,
    heightPx: json['height_px'] as int,
    isActive: json['is_active'] as bool,
    uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    deletedAt: json['deleted_at'] != null 
      ? DateTime.parse(json['deleted_at'] as String)
      : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'filePath': filePath,
    'fileSizeBytes': fileSizeBytes,
    'originalFormat': originalFormat,
    'storedFormat': storedFormat,
    'widthPx': widthPx,
    'heightPx': heightPx,
    'isActive': isActive,
    'uploadedAt': uploadedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
}
```

### Step 2.2: Create Profile Service

**File: `backend/lib/src/services/profile_service.dart`**

```dart
import 'package:image/image.dart' as img;
import 'package:postgres/postgres.dart';
import 'dart:io';
import 'dart:convert';

class ProfileService {
  final PostgresConnection connection;
  final String uploadsDir; // '/backend/uploads'

  ProfileService({
    required this.connection,
    required this.uploadsDir,
  });

  // Get user profile (with privacy check)
  Future<UserProfile> getProfile(String userId, String? requesterUserId) async {
    final result = await connection.query(
      '''
      SELECT id, email, username, profile_picture_url, about_me, 
             is_default_profile_picture, is_private_profile, profile_updated_at, created_at
      FROM "user" WHERE id = @userId
      ''',
      substitutionValues: {'userId': userId},
    );

    if (result.isEmpty) throw Exception('User not found');

    final row = result.first;
    final isPrivate = row['is_private_profile'] as bool;
    final isOwner = userId == requesterUserId;

    // Privacy check: only owner can view private profiles
    if (isPrivate && !isOwner) {
      throw Exception('Profile is private');
    }

    return UserProfile.fromJson(row);
  }

  // Update profile fields (username, about_me, is_private_profile)
  Future<UserProfile> updateProfile({
    required String userId,
    String? username,
    String? aboutMe,
    bool? isPrivateProfile,
  }) async {
    // Validation
    if (username != null) {
      username = username.trim();
      if (username.length < 3 || username.length > 32) {
        throw Exception('Username must be 3-32 characters');
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        throw Exception('Username must contain only alphanumeric and underscore');
      }
    }

    if (aboutMe != null) {
      aboutMe = aboutMe.trim();
      if (aboutMe.length > 500) {
        throw Exception('About me must be 0-500 characters');
      }
    }

    final updates = <String, dynamic>{};
    final substitutes = <String, dynamic>{'userId': userId, 'now': DateTime.now().toUtc()};

    if (username != null) {
      updates['username'] = '@username';
      substitutes['username'] = username;
    }
    if (aboutMe != null) {
      updates['about_me'] = '@aboutMe';
      substitutes['aboutMe'] = aboutMe;
    }
    if (isPrivateProfile != null) {
      updates['is_private_profile'] = '@isPrivateProfile';
      substitutes['isPrivateProfile'] = isPrivateProfile;
    }

    if (updates.isEmpty) {
      throw Exception('No changes provided');
    }

    updates['profile_updated_at'] = '@now';

    final setClause = updates.entries.map((e) => '${e.key} = ${e.value}').join(', ');

    final result = await connection.query(
      'UPDATE "user" SET $setClause WHERE id = @userId RETURNING *',
      substitutionValues: substitutes,
    );

    return UserProfile.fromJson(result.first);
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(String userId, List<int> imageBytes) async {
    // Size validation
    const maxSize = 5 * 1024 * 1024; // 5 MB
    if (imageBytes.length > maxSize) {
      throw Exception('File must be smaller than 5MB');
    }

    // Format detection & decoding
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Unable to process image file. Please ensure it\'s a valid JPEG or PNG.');
    }

    // Dimension validation
    if (image.width < 100 || image.width > 5000 || image.height < 100 || image.height > 5000) {
      throw Exception('Image dimension must be between 100x100 and 5000x5000 pixels');
    }

    // Detect original format
    String originalFormat = 'jpeg';
    if (imageBytes.length > 8 && imageBytes[0] == 0x89 && imageBytes[1] == 0x50) {
      originalFormat = 'png';
    }

    // Process: center crop to square, resize to 500x500
    final size = min(image.width, image.height);
    final left = (image.width - size) ~/ 2;
    final top = (image.height - size) ~/ 2;
    final cropped = img.copyCrop(image, x: left, y: top, width: size, height: size);
    final resized = img.copyResize(cropped, width: 500, height: 500);
    final processed = img.encodeJpg(resized, quality: 85);

    // Store file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '$userId-$timestamp.jpg';
    final filepath = 'profiles/$filename';
    final fullPath = '${uploadsDir}/profiles/$filename';

    Directory('${uploadsDir}/profiles/').createSync(recursive: true);
    await File(fullPath).writeAsBytes(processed);

    // Record in database
    await connection.execute(
      '''
      INSERT INTO "profile_image" 
      (id, user_id, file_path, file_size_bytes, original_format, stored_format, 
       width_px, height_px, is_active, uploaded_at)
      VALUES (gen_random_uuid(), @userId, @filePath, @size, @originalFormat, 'jpeg', 500, 500, true, NOW())
      ''',
      substitutionValues: {
        'userId': userId,
        'filePath': filepath,
        'size': processed.length,
        'originalFormat': originalFormat,
      },
    );

    // Update user profile
    final imageUrl = '/uploads/$filepath';
    await connection.execute(
      '''
      UPDATE "user" 
      SET profile_picture_url = @url, is_default_profile_picture = false, profile_updated_at = NOW()
      WHERE id = @userId
      ''',
      substitutionValues: {'url': imageUrl, 'userId': userId},
    );

    return imageUrl;
  }

  // Remove profile picture
  Future<void> removeProfilePicture(String userId) async {
    await connection.execute(
      '''
      UPDATE "profile_image" SET deleted_at = NOW() 
      WHERE user_id = @userId AND is_active = true AND deleted_at IS NULL
      ''',
      substitutionValues: {'userId': userId},
    );

    await connection.execute(
      '''
      UPDATE "user" 
      SET profile_picture_url = NULL, is_default_profile_picture = true, profile_updated_at = NOW()
      WHERE id = @userId
      ''',
      substitutionValues: {'userId': userId},
    );
  }
}
```

### Step 2.3: Create API Endpoints

**File: `backend/lib/src/endpoints/profile.dart`**

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ProfileEndpoints {
  final ProfileService profileService;

  ProfileEndpoints(this.profileService);

  Router get router => Router()
    ..get('/view/<userId>', _getProfile)
    ..patch('/edit', _updateProfile)
    ..post('/picture/upload', _uploadPicture)
    ..delete('/picture/remove', _removePicture);

  // GET /profile/view/{userId}
  Future<Response> _getProfile(Request request, String userId) async {
    try {
      final requesterUserId = request.context['userId'] as String?;
      final profile = await profileService.getProfile(userId, requesterUserId);
      return Response.ok(
        jsonEncode(profile.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } on Exception catch (e) {
      if (e.toString().contains('private')) {
        return Response.forbidden(jsonEncode({'error': 'FORBIDDEN', 'message': e.toString()}));
      }
      return Response.notFound(jsonEncode({'error': 'NOT_FOUND', 'message': 'User not found'}));
    }
  }

  // PATCH /profile/edit
  Future<Response> _updateProfile(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return Response.unauthorized('');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      
      final updated = await profileService.updateProfile(
        userId: userId,
        username: body['username'] as String?,
        aboutMe: body['aboutMe'] as String?,
        isPrivateProfile: body['isPrivateProfile'] as bool?,
      );

      return Response.ok(
        jsonEncode(updated.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } on Exception catch (e) {
      return Response(400, body: jsonEncode({'error': 'BAD_REQUEST', 'message': e.toString()}));
    }
  }

  // POST /profile/picture/upload (multipart form-data)
  Future<Response> _uploadPicture(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return Response.unauthorized('');

      // Parse multipart
      final form = await request.form().first;
      final pictureField = form.firstWhere((f) => f.name == 'picture');
      final imageBytes = await pictureField.part.toBytes();

      final imageUrl = await profileService.uploadProfilePicture(userId, imageBytes);

      return Response.ok(
        jsonEncode({
          'profilePictureUrl': imageUrl,
          'isDefaultProfilePicture': false,
          'profileUpdatedAt': DateTime.now().toIso8601String(),
          'message': 'Profile picture updated successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } on Exception catch (e) {
      final message = e.toString();
      if (message.contains('5MB')) {
        return Response(413, body: jsonEncode({'error': 'FILE_TOO_LARGE', 'message': message}));
      }
      return Response(400, body: jsonEncode({'error': 'BAD_REQUEST', 'message': message}));
    }
  }

  // DELETE /profile/picture/remove
  Future<Response> _removePicture(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return Response.unauthorized('');

      await profileService.removeProfilePicture(userId);

      return Response.ok(
        jsonEncode({
          'isDefaultProfilePicture': true,
          'profileUpdatedAt': DateTime.now().toIso8601String(),
          'message': 'Profile picture removed',
        }),
        headers: {'content-type': 'application/json'},
      );
    } on Exception catch (e) {
      return Response(500, body: jsonEncode({'error': 'INTERNAL_ERROR', 'message': e.toString()}));
    }
  }
}
```

### Step 2.4: Register Endpoints

In `backend/lib/server.dart`, add profile endpoints:

```dart
final profileService = ProfileService(connection: db, uploadsDir: '/backend/uploads');
final profileEndpoints = ProfileEndpoints(profileService);

final handler = Pipeline()
  .addMiddleware(logRequests())
  .addMiddleware(_authMiddleware)
  .addHandler(Router()
    ..mount('/profile', profileEndpoints.router)
    // ... other routes ...
  );
```

### Step 2.5: Add Static File Serving

In `backend/lib/server.dart`, add middleware to serve `/uploads` directory:

```dart
Middleware _staticFileMiddleware() => (handler) => (request) async {
  if (request.url.path.startsWith('uploads/')) {
    final filePath = '/backend/${request.url.path}';
    final file = File(filePath);
    if (await file.exists()) {
      return Response.ok(
        await file.readAsBytes(),
        headers: {
          'content-type': _mimeType(filePath),
          'cache-control': 'public, max-age=86400',
        },
      );
    }
  }
  return handler(request);
};

String _mimeType(String path) {
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.png')) return 'image/png';
  return 'application/octet-stream';
}
```

---

## Part 3: Frontend Implementation

### Step 3.1: Create Models

**File: `frontend/lib/core/models/user_profile.dart`**

```dart
class UserProfile {
  final String id;
  final String email;
  final String username;
  final String? profilePictureUrl;
  final String aboutMe;
  final bool isDefaultProfilePicture;
  final bool isPrivateProfile;
  final DateTime? profileUpdatedAt;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.profilePictureUrl,
    this.aboutMe = '',
    this.isDefaultProfilePicture = true,
    this.isPrivateProfile = false,
    this.profileUpdatedAt,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    profilePictureUrl: json['profilePictureUrl'] as String?,
    aboutMe: json['aboutMe'] as String? ?? '',
    isDefaultProfilePicture: json['isDefaultProfilePicture'] as bool? ?? true,
    isPrivateProfile: json['isPrivateProfile'] as bool? ?? false,
    profileUpdatedAt: json['profileUpdatedAt'] != null 
      ? DateTime.parse(json['profileUpdatedAt'] as String) 
      : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'profilePictureUrl': profilePictureUrl,
    'aboutMe': aboutMe,
    'isDefaultProfilePicture': isDefaultProfilePicture,
    'isPrivateProfile': isPrivateProfile,
    'profileUpdatedAt': profileUpdatedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  UserProfile copyWith({
    String? profilePictureUrl,
    String? aboutMe,
    bool? isDefaultProfilePicture,
    bool? isPrivateProfile,
    DateTime? profileUpdatedAt,
  }) => UserProfile(
    id: id,
    email: email,
    username: username,
    profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    aboutMe: aboutMe ?? this.aboutMe,
    isDefaultProfilePicture: isDefaultProfilePicture ?? this.isDefaultProfilePicture,
    isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
    profileUpdatedAt: profileUpdatedAt ?? this.profileUpdatedAt,
    createdAt: createdAt,
  );

  String? get displayImageUrl => isDefaultProfilePicture ? null : profilePictureUrl;
}
```

### Step 3.2: Create Riverpod Providers

**File: `frontend/lib/features/profile/providers/profile_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final profileServiceProvider = Provider((ref) => ProfileService());

// Get profile (with 5-minute cache TTL)
final userProfileProvider = FutureProvider.family<UserProfile, String>((ref, userId) async {
  final service = ref.watch(profileServiceProvider);
  return service.getProfile(userId);
});

// My own profile notifier
final myProfileNotifierProvider = StateNotifierProvider<
    MyProfileNotifier, AsyncValue<UserProfile>>((ref) {
  final service = ref.watch(profileServiceProvider);
  return MyProfileNotifier(service);
});
```

### Step 3.3: Create Profile Service

**File: `frontend/lib/features/profile/services/profile_service.dart`**

```dart
class ProfileService {
  static const String baseUrl = 'http://localhost:8081';
  final _client = http.Client();

  Future<UserProfile> getProfile(String userId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/profile/view/$userId'),
      headers: {'Authorization': 'Bearer ${await _getToken()}'},
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 403) {
      throw Exception('Profile is private');
    } else {
      throw Exception('Failed to load profile');
    }
  }

  Future<UserProfile> updateProfile({
    required String username,
    required String aboutMe,
    required bool isPrivateProfile,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/profile/edit'),
      headers: {
        'Authorization': 'Bearer ${await _getToken()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'aboutMe': aboutMe,
        'isPrivateProfile': isPrivateProfile,
      }),
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update profile');
    }
  }

  Future<String> uploadProfilePicture(List<int> imageBytes) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile/picture/upload'),
    );
    request.headers['Authorization'] = 'Bearer ${await _getToken()}';
    request.files.add(http.MultipartFile.fromBytes('picture', imageBytes));

    final response = await _client.send(request);
    final body = jsonDecode(await response.stream.bytesToString());

    if (response.statusCode == 200) {
      return body['profilePictureUrl'] as String;
    } else {
      throw Exception(body['message'] ?? 'Upload failed');
    }
  }

  Future<void> removeProfilePicture() async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/profile/picture/remove'),
      headers: {'Authorization': 'Bearer ${await _getToken()}'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove profile picture');
    }
  }

  Future<String> _getToken() async {
    // Retrieve from secure storage
    final storage = FlutterSecureStorage();
    return await storage.read(key: 'auth_token') ?? '';
  }
}
```

### Step 3.4: Create UI Screens

**File: `frontend/lib/features/profile/screens/profile_view_screen.dart`**

```dart
class ProfileViewScreen extends ConsumerWidget {
  final String userId;

  const ProfileViewScreen({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        data: (profile) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile picture
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: profile.displayImageUrl != null
                      ? NetworkImage('http://localhost:8081${profile.displayImageUrl}')
                      : null,
                  child: profile.displayImageUrl == null
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Username
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  profile.username,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              // About me
              if (profile.aboutMe.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(profile.aboutMe),
                ),
              const SizedBox(height: 24),
              // Edit button (only if own profile)
              _buildEditButton(context, ref),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context, WidgetRef ref) {
    // Check if this is own profile (compare userId with logged-in user)
    return Center(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileEditScreen(userId: userId)),
          );
        },
        child: const Text('Edit Profile'),
      ),
    );
  }
}
```

**File: `frontend/lib/features/profile/screens/profile_edit_screen.dart`** 

```dart
class ProfileEditScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileEditScreen({required this.userId});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  bool _isPrivate = false;
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
  }

  void _checkForChanges() {
    // Compare with original profile to enable Save button only when changed
    setState(() => hasChanges = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (hasChanges)
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile picture
              CircleAvatar(
                radius: 60,
                child: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _selectImage,
                ),
              ),
              const SizedBox(height: 16),
              // Username field
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  label: Text('Username'),
                  hintText: 'john_doe',
                ),
                onChanged: (_) => _checkForChanges(),
              ),
              const SizedBox(height: 16),
              // Bio field
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  label: Text('About me'),
                  hintText: 'Tell us about yourself',
                ),
                maxLines: 4,
                onChanged: (_) => _checkForChanges(),
              ),
              const SizedBox(height: 16),
              // Privacy toggle
              SwitchListTile(
                title: const Text('Make profile private'),
                value: _isPrivate,
                onChanged: (val) {
                  setState(() {
                    _isPrivate = val;
                    _checkForChanges();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      _uploadImage(bytes);
    }
  }

  Future<void> _uploadImage(List<int> bytes) async {
    try {
      final service = ref.read(profileServiceProvider);
      await service.uploadProfilePicture(bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    try {
      final service = ref.read(profileServiceProvider);
      await service.updateProfile(
        username: _usernameController.text,
        aboutMe: _bioController.text,
        isPrivateProfile: _isPrivate,
      );
      // Invalidate profile cache
      ref.refresh(userProfileProvider(widget.userId));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
```

---

## Testing

### Backend Testing

```bash
# Get profile
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/profile/view/USER_ID

# Update profile
curl -X PATCH http://localhost:8081/profile/edit \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"newname","aboutMe":"bio","isPrivateProfile":false}'

# Upload picture
curl -X POST http://localhost:8081/profile/picture/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "picture=@/path/to/image.jpg"

# Remove picture
curl -X DELETE http://localhost:8081/profile/picture/remove \
  -H "Authorization: Bearer $TOKEN"
```

### Frontend Testing

Run the Flutter app and manually test:

1. Navigate to profile screen → view profile picture, username, bio
2. Tap Edit → modify fields → Save button enabled
3. Upload new picture → verify display updates
4. Toggle privacy → verify persists across app restart
5. Delete picture → revert to default avatar

---

## Checklist

- [ ] Migrations created and run
- [ ] Backend models implemented
- [ ] Backend service created withvalidation
- [ ] Backend endpoints registered
- [ ] Static file middleware added
- [ ] Frontend models created
- [ ] Riverpod providers set up
- [ ] Frontend service created
- [ ] UI screens built
- [ ] Manual testing completed
- [ ] API endpoints tested with Postman
