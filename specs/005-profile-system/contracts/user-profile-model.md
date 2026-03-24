# Database Contract: User Profile Fields & ProfileImage Entity

**Feature**: 005-profile-system  
**Entities**: User (extended), ProfileImage (new)  
**Status**: Design Complete

## User Entity Schema Contract

```sql
-- Extended User table (Spec 002) with profile fields
CREATE TABLE "user" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(50) NOT NULL,  -- No longer UNIQUE (duplicate usernames allowed per Spec FR5)
  password_hash VARCHAR(255) NOT NULL,
  email_verified BOOLEAN DEFAULT false NOT NULL,
  -- NEW PROFILE FIELDS:
  profile_picture_url TEXT,
  about_me TEXT DEFAULT '',
  is_default_profile_picture BOOLEAN DEFAULT true NOT NULL,
  is_private_profile BOOLEAN DEFAULT false NOT NULL,
  profile_updated_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  
  CONSTRAINT email_format CHECK (email LIKE '%@%.%'),
  CONSTRAINT username_length CHECK (LENGTH(username) >= 3)
);

-- Profile indexes (new)
CREATE INDEX idx_user_is_private_profile ON "user"(is_private_profile);
CREATE INDEX idx_user_profile_updated_at ON "user"(profile_updated_at DESC);
-- Existing indexes
CREATE INDEX idx_user_email ON "user"(email);
CREATE INDEX idx_user_username ON "user"(username);
CREATE INDEX idx_user_created_at ON "user"(created_at DESC);
```

## User Profile Model Contract (Dart)

```dart
class UserProfile {
  final String id;  // UUID
  final String email;
  final String username;
  final String passwordHash;
  final bool emailVerified;
  
  // Profile fields (new)
  final String? profilePictureUrl;  // e.g., '/uploads/profiles/user-abc-1234.jpg', null = default
  final String aboutMe;             // 0-500 characters
  final bool isDefaultProfilePicture; // true when using default avatar
  final bool isPrivateProfile;      // true = only owner can view, false = public
  final DateTime? profileUpdatedAt;  // Last profile modification timestamp
  
  final DateTime createdAt;
  
  // Constructor, equality, toString omitted
}

// Serialization to/from JSON for API responses
extension UserProfileSerialization on UserProfile {
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
  
  static UserProfile fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    passwordHash: json['passwordHash'] as String,
    emailVerified: json['emailVerified'] as bool? ?? false,
    profilePictureUrl: json['profilePictureUrl'] as String?,
    aboutMe: json['aboutMe'] as String? ?? '',
    isDefaultProfilePicture: json['isDefaultProfilePicture'] as bool? ?? true,
    isPrivateProfile: json['isPrivateProfile'] as bool? ?? false,
    profileUpdatedAt: json['profileUpdatedAt'] != null 
      ? DateTime.parse(json['profileUpdatedAt'] as String)
      : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
```

## ProfileImage Entity Schema Contract

```sql
CREATE TABLE "profile_image" (
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
  
  -- Only one active image per user
  CONSTRAINT check_single_active UNIQUE (user_id, is_active) WHERE is_active = true,
  -- Deletion timestamp must be after upload
  CONSTRAINT check_deletion_time CHECK (deleted_at IS NULL OR deleted_at >= uploaded_at)
);

CREATE INDEX idx_profile_image_user_id ON "profile_image"(user_id);
CREATE INDEX idx_profile_image_is_active ON "profile_image"(is_active);
CREATE INDEX idx_profile_image_uploaded_at ON "profile_image"(uploaded_at DESC);
CREATE INDEX idx_profile_image_user_active ON "profile_image"(user_id, is_active) WHERE is_active = true;
```

## ProfileImage Model Contract (Dart)

```dart
class ProfileImage {
  final String id;  // UUID
  final String userId;  // FK to User.id
  final String filePath;  // Relative path: 'profiles/user-abc-1234.jpg'
  final int fileSizeBytes;  // Validation: 1 to 5242880 (5MB)
  final String originalFormat;  // 'jpeg' or 'png'
  final String storedFormat;  // Always 'jpeg' after processing
  final int widthPx;  // Always 500 after resize
  final int heightPx;  // Always 500 after resize
  final bool isActive;  // True if this is current profile picture
  final DateTime uploadedAt;
  final DateTime? deletedAt;  // Null if not deleted
  
  // Constructor, equality, toString omitted
}

extension ProfileImageSerialization on ProfileImage {
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
  
  static ProfileImage fromJson(Map<String, dynamic> json) => ProfileImage(
    id: json['id'] as String,
    userId: json['userId'] as String,
    filePath: json['filePath'] as String,
    fileSizeBytes: json['fileSizeBytes'] as int,
    originalFormat: json['originalFormat'] as String,
    storedFormat: json['storedFormat'] as String,
    widthPx: json['widthPx'] as int,
    heightPx: json['heightPx'] as int,
    isActive: json['isActive'] as bool,
    uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    deletedAt: json['deletedAt'] != null 
      ? DateTime.parse(json['deletedAt'] as String)
      : null,
  );
}
```

## Query Contracts (Backend)

### Query 1: Fetch full profile (with permission check)

```dart
Future<UserProfile?> getUserProfile(String userId) async {
  final result = await connection.query<Map<String, dynamic>>(
    '''
    SELECT id, email, username, password_hash, email_verified,
           profile_picture_url, about_me, is_default_profile_picture,
           is_private_profile, profile_updated_at, created_at
    FROM "user"
    WHERE id = @userId
    ''',
    substitutionValues: {'userId': userId},
  );
  
  if (result.isEmpty) return null;
  final row = result.first;
  
  // Permission check (if private, only owner can view)
  if (row['is_private_profile'] && !isOwner(userId)) {
    throw PermissionDenied('Profile is private');
  }
  
  return UserProfile.fromJson(row);
}
```

### Query 2: Get active profile image URL

```dart
Future<String?> getProfileImageUrl(String userId) async {
  final result = await connection.query<String>(
    '''
    SELECT file_path FROM "profile_image"
    WHERE user_id = @userId AND is_active = true AND deleted_at IS NULL
    ORDER BY uploaded_at DESC LIMIT 1
    ''',
    substitutionValues: {'userId': userId},
  );
  
  return result.isNotEmpty ? '/uploads/${result.first}' : null;
}
```

### Query 3: List all profile images for user (for admin/history)

```dart
Future<List<ProfileImage>> getUserProfileImages(String userId) async {
  final result = await connection.query<Map<String, dynamic>>(
    '''
    SELECT * FROM "profile_image"
    WHERE user_id = @userId AND deleted_at IS NULL
    ORDER BY uploaded_at DESC
    ''',
    substitutionValues: {'userId': userId},
  );
  
  return result.map(ProfileImage.fromJson).toList();
}
```

## Validation Rules

### User Profile Fields

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| profile_picture_url | TEXT | Valid file path or null | Generated by server, relative path format |
| about_me | TEXT | 0-500 characters | Trim whitespace, allow empty |
| is_default_profile_picture | BOOLEAN | true \| false | Set to false on upload, true on remove |
| is_private_profile | BOOLEAN | true \| false | Default false (public) |
| profile_updated_at | TIMESTAMP | Nullable | Set on profile edit or image upload |

### ProfileImage Entity

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| file_size_bytes | INTEGER | 1 byte - 5 MB | Check at upload |
| original_format | VARCHAR | 'jpeg' \| 'png' | Validated from file magic bytes |
| stored_format | VARCHAR | Always 'jpeg' | Standardized format after processing |
| width_px, height_px | INTEGER | 100-5000 | After resize to 500x500 |
| is_active | BOOLEAN | One true per user | UNIQUE constraint enforced |

## Access Patterns

1. **Public profile view** (no auth required):
   ```sql
   SELECT * FROM "user" WHERE id = $1 AND is_private_profile = false
   ```

2. **Own profile view** (authenticated, user_id = current_user):
   ```sql
   SELECT * FROM "user" WHERE id = $1
   ```

3. **Upload new picture**:
   - INSERT into profile_image
   - UPDATE user SET profile_picture_url, is_default_profile_picture, profile_updated_at
   - OLD image is_active flag left as-is (multiple is_active=false allowed)

4. **Remove picture**:
   - UPDATE profile_image SET deleted_at WHERE user_id = $1 AND is_active = true
   - UPDATE user SET profile_picture_url = NULL, is_default_profile_picture = true, profile_updated_at = NOW()

5. **Search public profiles**:
   ```sql
   SELECT id, username, profile_picture_url FROM "user" 
   WHERE is_private_profile = false AND LOWER(username) LIKE LOWER(@query)
   ORDER BY profile_updated_at DESC
   ```
