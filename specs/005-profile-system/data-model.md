# Phase 1 Design: Data Model

**Date**: 2026-03-11  
**Feature**: 005-profile-system  
**Status**: Design Complete

## Data Model Overview

User profile system extends the User entity with profile-specific fields and adds a new ProfileImage entity for tracking and serving uploaded profile pictures.

## Entity Updates & Additions

### Entity 1: User (Extended)

**Purpose**: Existing User entity from Spec 002, extended with profile-specific fields

**New Fields** (additions to existing User table):
- `profile_picture_url` (TEXT, nullable): Path to user's current profile picture (e.g., `/uploads/profiles/user-abc123-1234567890.jpg`)
- `about_me` (TEXT, default ''): User's bio or status message (max 500 characters, enforced in app)
- `is_default_profile_picture` (BOOLEAN, default true): Flag indicating whether using default avatar or custom upload
- `is_private_profile` (BOOLEAN, default false): Privacy toggle (true = only owner can view, false = public)
- `profile_updated_at` (TIMESTAMP WITH TIME ZONE, nullable): Last update timestamp for profile (used for cache invalidation)

**Updated Schema**:
```sql
-- Extending existing "user" table (Spec 002)
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS about_me TEXT DEFAULT '';
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS is_default_profile_picture BOOLEAN DEFAULT true NOT NULL;
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS is_private_profile BOOLEAN DEFAULT false NOT NULL;
ALTER TABLE "user" ADD COLUMN IF NOT EXISTS profile_updated_at TIMESTAMP WITH TIME ZONE;
```

**Constraints**:
- `about_me`: Max 500 characters (validated in application layer)
- `is_private_profile`: Enforced as boolean (no null values)
- `is_default_profile_picture`: Set to false when custom image uploaded, true when deleted

**Indexes**:
```sql
-- New indexes for profile queries
CREATE INDEX IF NOT EXISTS idx_user_is_private_profile ON "user"(is_private_profile);
CREATE INDEX IF NOT EXISTS idx_user_profile_updated_at ON "user"(profile_updated_at DESC);
```

**Relationships**:
- One-to-Many with ProfileImage: User can have multiple profile picture uploads (current one referenced by profile_picture_url)

---

### Entity 2: ProfileImage (New)

**Purpose**: Auditable record of profile picture uploads, supports future recovery and history features

**Fields**:
- `id` (UUID, PRIMARY KEY DEFAULT gen_random_uuid()): Unique image record identifier
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL): Owner of the image
- `file_path` (TEXT, NOT NULL): Stored file path (e.g., `profiles/user-abc123-1234567890.jpg`) - relative path from uploads root
- `file_size_bytes` (INTEGER, NOT NULL): File size in bytes (validation: 1-5242880 for 5MB max)
- `original_format` (VARCHAR(10), NOT NULL): Original format ('jpeg' or 'png')
- `stored_format` (VARCHAR(10), NOT NULL): Format after processing (always 'jpeg' for standardization)
- `width_px` (INTEGER, NOT NULL): Original image width after processing (500px for profiles)
- `height_px` (INTEGER, NOT NULL): Original image height after processing (500px for profiles)
- `is_active` (BOOLEAN, DEFAULT false): Flag indicating if this is the current profile picture (only one per user can be true)
- `uploaded_at` (TIMESTAMP WITH TIME ZONE, DEFAULT NOW(), NOT NULL): Upload timestamp
- `deleted_at` (TIMESTAMP WITH TIME ZONE, nullable): Soft delete timestamp (allows recovery)

**Schema**:
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
  
  CONSTRAINT check_deletion_time CHECK (deleted_at IS NULL OR deleted_at >= uploaded_at),
  CONSTRAINT check_single_active UNIQUE (user_id, is_active) WHERE is_active = true
);

CREATE INDEX idx_profile_image_user_id ON "profile_image"(user_id);
CREATE INDEX idx_profile_image_is_active ON "profile_image"(is_active);
CREATE INDEX idx_profile_image_uploaded_at ON "profile_image"(uploaded_at DESC);
CREATE INDEX idx_profile_image_user_active ON "profile_image"(user_id, is_active) WHERE is_active = true;
```

**Constraints**:
- `file_size_bytes`: 1 byte minimum, 5MB (5242880 bytes) maximum
- `original_format`: Only 'jpeg' or 'png' (validated on upload)
- `stored_format`: Standardized to 'jpeg' for consistency
- `is_active`: Only one image per user can be is_active = true (UNIQUE constraint with WHERE clause)
- `deleted_at`: Cannot be before uploaded_at (soft delete audit trail)

**Relationships**:
- Many-to-One with User: Multiple images belong to one user
- Cascade delete on user deletion: ProfileImage records deleted if user deleted

**Design Notes**:
- `file_path` stored as relative path so full URL constructed by application (`/uploads/{file_path}`)
- `is_active` flag allows tracking which image is currently displayed (one true per user)
- `deleted_at` enables recovery/historical queries without hard delete
- `original_format` vs `stored_format` supports migration to different output format in future

---

### Entity 3: Data Model Relationships

**Diagram**:

```
┌─────────────────┐
│     User        │
├─────────────────┤
│ id (PK)         │
│ email           │
│ username        │
│ password_hash   │
│ ...             │
│ profile_picture_url (new)
│ about_me (new)
│ is_default_profile_picture (new)
│ is_private_profile (new)
│ profile_updated_at (new)
└────────┬────────┘
         │ (1:N)
         │ ONE_TO_MANY
         │
┌─────────┴────────┐
│  ProfileImage    │
├──────────────────┤
│ id (PK)          │
│ user_id (FK)     │
│ file_path        │
│ file_size_bytes  │
│ original_format  │
│ stored_format    │
│ width_px         │
│ height_px        │
│ is_active        │
│ uploaded_at      │
│ deleted_at       │
└──────────────────┘
```

**Access Patterns**:

1. **Get current profile picture URL**:
   ```sql
   SELECT profile_picture_url FROM "user" WHERE id = $1;
   -- Returns: '/uploads/profiles/user-abc-1234567890.jpg' or NULL (default)
   ```

2. **Get full profile info**:
   ```sql
   SELECT id, username, about_me, profile_picture_url, is_private_profile, profile_updated_at 
   FROM "user" 
   WHERE id = $1;
   ```

3. **Check if profile is viewable** (authorization):
   ```sql
   SELECT is_private_profile FROM "user" WHERE id = $1;
   -- If is_private_profile = true and requester != user_id: DENY
   -- If is_private_profile = false: ALLOW
   ```

4. **Get active profile image record**:
   ```sql
   SELECT * FROM "profile_image" 
   WHERE user_id = $1 AND is_active = true AND deleted_at IS NULL
   ORDER BY uploaded_at DESC
   LIMIT 1;
   ```

5. **List all profile images for user** (for UI history):
   ```sql
   SELECT * FROM "profile_image"
   WHERE user_id = $1 AND deleted_at IS NULL
   ORDER BY uploaded_at DESC;
   ```

6. **Find default avatar users** (analytics):
   ```sql
   SELECT COUNT(*) FROM "user"
   WHERE is_default_profile_picture = true;
   ```

---

## Migration Scripts

### Migration 011: Add Profile Fields to User Table

**File**: `backend/migrations/011_add_profile_fields_to_user.dart`

```dart
import 'package:database/database.dart';

class Migration011 extends Migration {
  @override
  String get name => '011_add_profile_fields_to_user';

  @override
  Future<void> up(PostgresConnection connection) async {
    // Add new columns to user table
    await connection.execute('''
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS about_me TEXT DEFAULT '';
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS is_default_profile_picture BOOLEAN DEFAULT true NOT NULL;
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS is_private_profile BOOLEAN DEFAULT false NOT NULL;
      ALTER TABLE "user" ADD COLUMN IF NOT EXISTS profile_updated_at TIMESTAMP WITH TIME ZONE;
    ''');
    
    // Create indexes
    await connection.execute('''
      CREATE INDEX IF NOT EXISTS idx_user_is_private_profile ON "user"(is_private_profile);
      CREATE INDEX IF NOT EXISTS idx_user_profile_updated_at ON "user"(profile_updated_at DESC);
    ''');
  }

  @override
  Future<void> down(PostgresConnection connection) async {
    // Drop indexes
    await connection.execute('DROP INDEX IF EXISTS idx_user_profile_updated_at;');
    await connection.execute('DROP INDEX IF EXISTS idx_user_is_private_profile;');
    
    // Remove columns
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

### Migration 012: Create ProfileImage Table

**File**: `backend/migrations/012_create_profile_image_table.dart`

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
        
        CONSTRAINT check_deletion_time CHECK (deleted_at IS NULL OR deleted_at >= uploaded_at),
        CONSTRAINT check_single_active UNIQUE (user_id, is_active) WHERE is_active = true
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

---

## Dart Model Classes

### User Profile Model (Frontend)

```dart
// lib/core/models/user.dart (extended)

class UserProfile {
  final String id;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final String aboutMe;
  final bool isDefaultProfilePicture;
  final bool isPrivateProfile;
  final DateTime? profileUpdatedAt;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.profilePictureUrl,
    this.aboutMe = '',
    this.isDefaultProfilePicture = true,
    this.isPrivateProfile = false,
    this.profileUpdatedAt,
    required this.createdAt,
  });

  // Serialization
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
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

  // Copyable for immutable updates
  UserProfile copyWith({
    String? profilePictureUrl,
    String? aboutMe,
    bool? isDefaultProfilePicture,
    bool? isPrivateProfile,
    DateTime? profileUpdatedAt,
  }) => UserProfile(
    id: id,
    username: username,
    email: email,
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

### ProfileImage Model (Backend)

```dart
// backend/lib/src/models/profile_image.dart

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

  // Serialization
  factory ProfileImage.fromJson(Map<String, dynamic> json) => ProfileImage(
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

---

## Summary

| Entity | Type | Purpose | Key Fields |
|--------|------|---------|-----------|
| User (extended) | Table Update | Store user profile metadata | profile_picture_url, about_me, is_private_profile, is_default_profile_picture |
| ProfileImage | New Table | Audit trail of profile pictures | file_path, is_active, uploaded_at, deleted_at |

**Total Migrations**: 2 (011, 012)  
**New Tables**: 1 (profile_image)  
**Modified Tables**: 1 (user - added 5 columns)  
**New Indexes**: 6 (for profile queries and active image lookup)
