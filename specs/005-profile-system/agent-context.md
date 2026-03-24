---
description: Mobile Messenger - User Profile System Feature Context
version: 1.0.0
created: 2026-03-11
updated: 2026-03-11
reference: specs/005-profile-system/
---

# Agent Context: User Profile System (Spec 005)

## Feature Overview

The User Profile System (Spec 005) enables users to view and edit their profiles, upload profile pictures, and control profile visibility. This context provides architectural knowledge for agents working on profile-related code.

## Database Schema (Extended)

### User Table Extensions
```sql
-- New columns added to existing user table:
profile_picture_url TEXT                              -- Relative path to profile image
about_me TEXT DEFAULT ''                              -- User bio (0-500 chars)
is_default_profile_picture BOOLEAN DEFAULT true       -- Flag for default avatar
is_private_profile BOOLEAN DEFAULT false              -- Privacy toggle
profile_updated_at TIMESTAMP WITH TIME ZONE           -- Last profile modification
```

### ProfileImage Table (New)
```sql
CREATE TABLE profile_image (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES user(id),
  file_path TEXT NOT NULL,                            -- /profiles/userId-timestamp.jpg
  file_size_bytes INTEGER,                            -- Stored: 1-5242880 (5MB)
  original_format VARCHAR(10),                        -- 'jpeg', 'png'
  stored_format VARCHAR(10) DEFAULT 'jpeg',
  width_px INTEGER,                                    -- 500 after processing
  height_px INTEGER,                                   -- 500 after processing
  is_active BOOLEAN DEFAULT false,                    -- One per user
  uploaded_at TIMESTAMP WITH TIME ZONE,
  deleted_at TIMESTAMP WITH TIME ZONE                 -- Soft delete
)
```

## API Endpoints

### Public Endpoints (No Auth Required)
- `GET /profile/view/{userId}` - View public profile (privacy check enforced)
  
### Authenticated Endpoints (JWT Required)
- `PATCH /profile/edit` - Update profile (username, bio, privacy)
- `POST /profile/picture/upload` - Upload image (multipart/form-data)
- `DELETE /profile/picture/remove` - Remove custom image

## Backend Architecture

### ProfileService (Dart)
```dart
class ProfileService {
  Future<UserProfile> getProfile(String userId, String? requesterUserId)
    // Privacy check: if private && not owner -> throw PermissionDenied
  
  Future<UserProfile> updateProfile({
    required String userId,
    String? username,
    String? aboutMe,
    bool? isPrivateProfile,
  })
  
  Future<String> uploadProfilePicture(String userId, List<int> imageBytes)
    // Validation: format (jpeg/png), size (1-5MB), dimensions (100-5000px)
    // Processing: center crop to square, resize to 500x500, compress jpeg 85%
    // Returns: /uploads/profiles/userId-timestamp.jpg
  
  Future<void> removeProfilePicture(String userId)
    // Soft delete ProfileImage, revert user to default
}
```

### Image Processing Logic
- Detection: JPEG (0xFF 0xD8) vs PNG (0x89 0x50)
- Validation: Decode via `image` package; check dimensions
- Processing: `image.copyCrop()` center square, `image.copyResize()` 500x500, `image.encodeJpg()` quality:85
- Storage: `/backend/uploads/profiles/{userId}-{timestamp}.jpg`
- Serving: Shelf static middleware with whitelist

### Error Codes
```dart
400 Bad Request    // Invalid username (3-32 chars), invalid image format/dimensions
401 Unauthorized   // Missing/invalid JWT
403 Forbidden      // Trying to edit other's profile, viewing private profile
404 Not Found      // User doesn't exist
413 Payload Large  // File > 5MB
500 Server Error   // Database/file system error
```

## Frontend Architecture

### Riverpod Providers
```dart
// Cached profile data (5-minute TTL)
final userProfileProvider = FutureProvider.family<UserProfile, String>

// Form state for editing
final profileFormNotifierProvider = StateNotifierProvider

// My own profile (auto-refreshes on edit)
final myProfileNotifierProvider = StateNotifierProvider
```

### Screens
1. **ProfileViewScreen** (Read-only)
   - Display: Profile picture (default or custom), username, bio, privacy indicator
   - Actions: Edit button (if own profile), refresh button
   
2. **ProfileEditScreen** (Edit form)
   - Fields: Username, About me (bio), Privacy toggle
   - Actions: Image picker, Save button (enabled only on changes), Cancel
   - Error handling: Form state preserved on validation error

### Profile Picture Handling
- Display: `CircleAvatar(backgroundImage: NetworkImage(imageUrl))` for custom, default icon if null
- Upload: `image_picker` package → `profileService.uploadProfilePicture(bytes)`
- Remove: `profileService.removeProfilePicture()` → revert to default
- Caching: Riverpod manages cache invalidation on edit

## Key Behaviors

### Privacy Enforcement
- Public (default): Anyone can GET /profile/view/{userId}
- Private: Only userId == requester_id can view; others get 403
- Backend check: `if (profile.isPrivate && requester != owner) throw PermissionDenied`

### Image Processing
- No client-side cropping (direct server processing)
- Server handles: crop to square (center), resize to 500x500, compress JPEG 85%
- Response: URL like `/uploads/profiles/user-abc123-1234567890.jpg`

### Cache Strategy
- Frontend: 5-minute TTL via Riverpod (no explicit invalidation timer)
- Manual refresh: User taps refresh button or edits profile
- Invalidation: `ref.refresh(userProfileProvider(userId))` after edit

### Validation Rules
- **Username**: 3-32 chars, alphanumeric + underscore, trim whitespace
- **About me**: 0-500 chars, trim whitespace (optional)
- **Image**: JPEG/PNG, 1-5MB, 100x100 to 5000x5000 pixels
- **Privacy**: Boolean (0 or 1), default 0 (public)

## Common Implementation Patterns

### Backend: Check Privacy
```dart
if (profile.isPrivateProfile && profile.userId != requesterUserId) {
  throw Exception('Profile is private');
}
```

### Backend: Process Image
```dart
final image = img.decodeImage(imageBytes);
final cropped = img.copyCrop(image, x: left, y: top, width: size, height: size);
final resized = img.copyResize(cropped, width: 500, height: 500);
final processed = img.encodeJpg(resized, quality: 85);
```

### Frontend: Display Profile Picture
```dart
CircleAvatar(
  backgroundImage: profile.displayImageUrl != null
    ? NetworkImage('http://localhost:8081${profile.displayImageUrl}')
    : null,
  child: profile.displayImageUrl == null ? Icon(Icons.person) : null,
)
```

### Frontend: Update Profile with Changes Detection
```dart
bool hasChanges = username != original.username ||
                  aboutMe != original.aboutMe ||
                  isPrivate != original.isPrivateProfile;
                  
// Save button enabled only if hasChanges
ElevatedButton(
  onPressed: hasChanges ? _saveProfile : null,
  child: Text('Save'),
)
```

## Integration Points

- **Spec 006 (User Search)**: Filter results by `is_private_profile = false`
- **Spec 007 (Chat Invitations)**: Display profile picture in invite list
- **Spec 008 (Chat List)**: Show profile pictures of chat members
- **Spec 009 (Messaging)**: Display sender's profile picture in messages
- **Future: Friends System**: Replace `is_private_profile` boolean with friend-based ACL

## File Locations

**Backend**:
- Service: `backend/lib/src/services/profile_service.dart`
- Endpoints: `backend/lib/src/endpoints/profile.dart`
- Models: `backend/lib/src/models/{user_profile.dart, profile_image.dart}`
- Migrations: `backend/migrations/{011_add_profile_fields_to_user.dart, 012_create_profile_image_table.dart}`

**Frontend**:
- Models: `frontend/lib/core/models/user_profile.dart`
- Providers: `frontend/lib/features/profile/providers/profile_providers.dart`
- Service: `frontend/lib/features/profile/services/profile_service.dart`
- Screens: `frontend/lib/features/profile/screens/{profile_view_screen.dart, profile_edit_screen.dart}`

## Dependencies

**Dart Packages**:
- Backend: `image: ^4.0.0` (image processing), `shelf`, `postgres`
- Frontend: `flutter_riverpod`, `http`, `image_picker`, `flutter_secure_storage`

**External**: None (local file storage, no cloud services)

## Testing Checklist

- [ ] Privacy enforcement: Private profiles return 403 to non-owners
- [ ] Image validation: Correct rejection of format/size/dimension errors
- [ ] Image processing: Produces correct 500x500 JPEG
- [ ] Profile editing: Changes persist to database
- [ ] Cache behavior: 5-minute TTL works, manual refresh invalidates
- [ ] Error handling: Specific validation messages, generic server errors
- [ ] Concurrent uploads: No race conditions with file naming
- [ ] Soft delete: Old images marked deleted_at, not removed
