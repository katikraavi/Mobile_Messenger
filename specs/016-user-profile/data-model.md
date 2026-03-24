# Data Model & Contracts: User Profile System

**Phase**: 1 - Design & Contracts  
**Generated**: March 13, 2026  
**Input**: Feature specification + Phase 0 research findings

---

## Core Entities

### User (Extended)

**Purpose**: Represents authenticated user with profile information

```dart
class User {
  final String userId;              // PK: unique user identifier (UUID)
  final String email;               // unique email from registration
  final String username;            // 3-32 chars, editable, duplicates allowed
  final String? profilePictureUrl;  // nullable: CDN URL or null for default
  final String aboutMe;             // 0-500 chars, optional bio (default: "")
  final bool isDefaultProfilePicture; // true = default avatar, false = custom upload
  final bool isPrivateProfile;      // true = private, false = public (default: false)
  final DateTime createdAt;         // account creation timestamp
  final DateTime? updatedAt;        // profile last modification timestamp
  final bool emailVerified;         // from authentication layer
  final String? verificationToken;  // for email verification (NOT editable in profile)
}
```

**Validation Rules**:
- username: 3-32 characters, alphanumeric + underscore + hyphen, trimmed
- username: Duplicates allowed (users identified by userId not username uniqueness)
- aboutMe: 0-500 characters after trimming
- profilePictureUrl: Must be secure HTTPS URL or null
- isPrivateProfile: Default false for new users (public by default)

**Key Relationships**:
- User → many ProfileImages (images uploaded by this user)
- User → many Messages (sent by this user)
- User ← many Messages (received by this user)
- User → many ChatMembers (chats user participates in)

**Database Migration**: User table updated with profile fields (run before feature deployment)

---

### ProfileImage (New)

**Purpose**: Stores metadata for uploaded profile pictures

```dart
class ProfileImage {
  final String imageId;           // PK: unique image identifier (UUID)
  final String userId;            // FK: user who owns this image
  final String imageUrl;          // CDN/direct URL to compressed image (500x500px)
  final int fileSize;             // bytes: for logging and analytics
  final String format;            // JPEG or PNG (enum/string)
  final DateTime uploadedAt;      // timestamp when uploaded
  final DateTime? deletedAt;      // soft delete: null = active, timestamp = deleted
  final String? checksumHa256;    // optional: content hash for deduplication
}
```

**Validation Rules**:
- imageUrl: Must be secure HTTPS URL
- fileSize: Positive integer, <= 5MB (5,242,880 bytes)
- format: One of ["JPEG", "PNG"] (case consistent server-side)
- deletedAt: Soft delete pattern (no hard deletion of image records)

**Lifecycle**:
1. User selects image from gallery/camera
2. Client validates (format, size, dimensions)
3. Client uploads multipart POST to /api/profile/picture
4. Server validates, compresses to 500x500px, stores
5. ProfileImage record created with imageUrl
6. User.profilePictureUrl updated to point to this image
7. User.isDefaultProfilePicture set to false
8. Image served via CDN or direct URL for next 5+ minutes (cached)
9. User can delete: ProfileImage.deletedAt set, User.profilePictureUrl → null
10. User.isDefaultProfilePicture set back to true, default avatar displayed

---

## State Models (Client-Side)

### UserProfileState (Riverpod)

**Purpose**: Read-only profile data for display

```dart
class UserProfileState {
  final String userId;
  final String username;
  final String? profilePictureUrl;
  final String aboutMe;
  final bool isPrivateProfile;
  final DateTime? lastUpdated;
  
  bool hasCustomPicture() => profilePictureUrl != null;
  bool hasEmptyBio() => aboutMe.trim().isEmpty;
}
```

**Provider Pattern**:
```dart
final userProfileProvider = FutureProvider<UserProfileState>((ref) async {
  final userId = ref.watch(authProvider).userId;
  // Fetch from backend or local cache
  return await profileApiService.fetchProfile(userId);
});
```

---

### ProfileFormState (Riverpod StateNotifier)

**Purpose**: Editable form state for profile editor

```dart
class ProfileFormState {
  final String username;           // current input value
  final String aboutMe;            // current input value
  final File? pendingImage;        // selected but not yet uploaded
  final bool isPrivateProfile;     // current toggle state
  
  final bool isDirty;              // true if any field changed from original
  final bool isLoading;            // true during API call
  final ValidationError? error;    // validation error (if any)
  
  final String? originalUsername;  // for dirty detection
  final String? originalAboutMe;
  final bool? originalIsPrivate;
}

enum ValidationError {
  invalidUsername,        // 3-32 chars, alphanumeric+underscore
  invalidBio,             // max 500 chars
  imageFormatInvalid,     // not JPEG/PNG
  imageTooLarge,          // > 5MB
  imageDimensionsInvalid, // not 100x100 to 5000x5000
  networkError,
  serverError,
}
```

**State Transitions**:
- Initialize: Load current profile values into form (from UserProfileState)
- Edit: Update username/bio/image fields → mark isDirty = true
- Validate: Check each field → set error or clear
- Save: Send to backend → isLoading = true → wait for response → setIsDirty = false
- Reset: Revert all fields to original values → isDirty = false
- Error: Failed validation or network error → display error message

---

## API Contracts

### Profile View / Fetch

```
GET /api/profile/:userId
Authorization: Bearer {token}

Response (200 OK):
{
  "userId": "uuid-1234",
  "username": "alice_wonder",
  "email": "alice@example.com",
  "profilePictureUrl": "https://cdn.app/profile-uuid-1234.jpg",
  "aboutMe": "Coffee lover ☕",
  "isPrivateProfile": false,
  "updatedAt": "2026-03-10T14:32:00Z"
}

Response (404 Not Found):
{ "error": "User not found" }

Response (403 Forbidden):
{ "error": "Profile is private" }  # Future: when permission layer implemented
```

---

### Profile Update

```
PUT /api/profile
Authorization: Bearer {token}
Content-Type: application/json

Request:
{
  "username": "alice_wonderland",
  "aboutMe": "Coffee & books 📚",
  "isPrivateProfile": false
}

Response (200 OK):
{
  "success": true,
  "profile": {
    "userId": "uuid-1234",
    "username": "alice_wonderland",
    "profilePictureUrl": "https://cdn.app/profile-uuid-1234.jpg",
    "aboutMe": "Coffee & books 📚",
    "isPrivateProfile": false,
    "updatedAt": "2026-03-13T09:15:00Z"
  }
}

Response (400 Bad Request):
{ "error": "Username must be 3-32 characters" }

Response (401 Unauthorized):
{ "error": "Invalid credentials" }
```

---

### Profile Picture Upload

```
POST /api/profile/picture
Authorization: Bearer {token}
Content-Type: multipart/form-data

Request:
{
  "image": <binary file data>,
  "filename": "profile.jpg"
}

Response (200 OK):
{
  "success": true,
  "imageUrl": "https://cdn.app/profile-uuid-1234-20260313-1234567.jpg",
  "fileSize": 45670,
  "format": "JPEG"
}

Response (400 Bad Request - Format):
{ "error": "Only JPEG and PNG formats are supported" }

Response (400 Bad Request - Dimensions):
{ "error": "Image must be between 100x100 and 5000x5000 pixels" }

Response (413 Payload Too Large):
{ "error": "File must be smaller than 5MB" }

Response (401 Unauthorized):
{ "error": "Invalid credentials" }
```

---

### Profile Picture Delete

```
DELETE /api/profile/picture
Authorization: Bearer {token}

Response (200 OK):
{
  "success": true,
  "message": "Profile picture removed"
}

Response (404 Not Found):
{ "error": "No custom profile picture to delete" }

Response (401 Unauthorized):
{ "error": "Invalid credentials" }
```

---

## UI Component Contracts

### ProfileViewScreen

**Input Props**:
```dart
class ProfileViewScreenProps {
  final String userId;           // whose profile to display
  final bool isOwnProfile;       // controls edit button visibility
  final User? currentUser;       // optional: pre-loaded user data (optimizes loading)
}
```

**Output Events**:
```dart
enum ProfileViewEvent {
  editPressed,      // user tapped Edit button → navigate to ProfileEditScreen
  messagePressed,   // user tapped Message button (future)
  addFriendPressed, // user tapped Add Friend button (future)
}
```

**Display Contract**:
- Profile picture: 120x120 circular image (or default avatar)
- Username: Large bold text, non-editable in view mode
- About me: Multi-line text area, word-wrapped
- Privacy indicator: Lock icon if isPrivateProfile = true
- Edit button: Visible only if isOwnProfile = true
- Message/Add button: Visible only if isOwnProfile = false (future)
- Loading state: Skeleton loaders while fetching
- Error state: Retry button + error message
- Empty bio state: Show placeholder "No bio added yet"

**State Management**:
- Watch `userProfileProvider.select((p) => p.when(...))` for loading/error/data states
- Refresh on manual pull gesture
- Lazy-load large profile pictures

---

### ProfileEditScreen

**Input Props**:
```dart
class ProfileEditScreenProps {
  final User currentUserProfile;  // initial values for form
}
```

**Output Events**:
```dart
enum ProfileEditEvent {
  saved,            // profile saved successfully → pop screen
  cancelled,        // user cancelled → pop without saving
  validationError,  // form validation failed → show inline errors
  networkError,     // upload failed → show retry
}
```

**Display Contract**:
- Username text field: Pre-populated, 3-32 char limit, live character counter
- About me text area: Pre-populated, max 500 chars, live character counter
- Profile picture display: Current picture (default or custom) with edit overlay
- Upload/Change picture button: Opens image picker (gallery + camera options)
- Remove picture button: Visible only if custom picture exists, with confirmation
- Privacy toggle: Switch for public/private
- Save button: Disabled until isDirty = true (only enable on actual changes)
- Cancel button: Always enabled, reverts all changes
- Loading indicator: Shows during image upload or profile save
- Error messages: Inline validation errors for each field
- Success message: "Profile saved!" toast notification

**Form Validation** (real-time):
- Username: Minimum 3 characters, maximum 32, alphanumeric + underscore + hyphen only
- About me: Maximum 500 characters (no minimum)
- Image: Format (JPEG/PNG), size (≤5MB), dimensions (100-5000px)
- Show error message inline under each field on validation failure

---

### Image Upload Widget

**Input Props**:
```dart
class ImageUploadProps {
  final File? currentImage;     // null = show default, File = show current
  final VoidCallback onImageSelected;
  final VoidCallback onImageRemoved;
  final String? errorMessage;   // validation error to display
  final bool isLoading;
}
```

**Display Contract**:
- Square image preview (200x200 or 150x150)
- Camera button (opens camera)
- Gallery button (opens gallery in image_picker)
- Remove button (if custom image exists)
- Overlay on hover/tap: "Change picture"
- Progress indicator during upload
- Error message display (format, size, dimensions)
- Loading state: Dim image + spinner

**Validation Feedback**:
- "Only JPEG and PNG formats are supported"
- "File must be smaller than 5MB"
- "Image must be between 100x100 and 5000x5000 pixels"

---

## Validation Rules (Shared Client + Server)

| Field | Min | Max | Pattern | Error Message |
|-------|-----|-----|---------|----------------|
| username | 3 | 32 | `^[a-zA-Z0-9_-]*$` | Username: 3-32 characters, letters/numbers/underscore/hyphen |
| aboutMe | 0 | 500 | any UTF-8 | Bio cannot exceed 500 characters |
| image format | - | - | JPEG, PNG | Only JPEG and PNG formats are supported |
| image size | - | 5 MB | - | File must be smaller than 5MB |
| image dims | 100x100 | 5000x5000 | - | Image must be between 100x100 and 5000x5000 pixels |

---

## Success Metrics (Acceptance Criteria)

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| Profile loads | 500ms | Time from navigation to full profile display |
| Image upload | 2 sec | Time from confirmation to new image visible on profile |
| Changes visible to others | 2 sec | Time from save to other users seeing update |
| Form state persists on error | - | Edit form values preserved after validation error |
| Privacy toggle works | - | Setting persists across app restart |
| Duplicate usernames allowed | - | No uniqueness constraint enforced |
| Offline-capable | - | Profile displays from cache if network unavailable |

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ User Interaction Flow                                       │
└─────────────────────────────────────────────────────────────┘

1. VIEW OWN PROFILE
   App.dart (Profile Tab) 
     → ProfileViewScreen(currentUser: widget.user)
       → Displays profile immediately from passed currentUser
       → Watch userProfileProvider for fresh data (5-min cache)
       → Show lock icon if isPrivateProfile = true

2. EDIT PROFILE
   ProfileViewScreen (Edit button)
     → ProfileEditScreen(currentUserProfile: profile)
       → Initialize form with current values
       → User edits text fields → isDirty = true
       → Save button enabled

3. UPDATE TEXT FIELDS
   ProfileEditScreen
     → Watch profileFormStateProvider
       → Validate on blur or after each keystroke
       → Show inline errors
       → Update isDirty flag

4. IMAGE UPLOAD
   ProfileEditScreen (Upload button)
     → Image picker: gallery/camera
       → User selects image → File returned
       → Validate client-side (format, size, dims)
       → Show error if invalid, allow retry
       → If valid: mark pendingImage in form state

5. SAVE PROFILE (with image)
   ProfileEditScreen (Save button)
     → If pendingImage exists:
         → POST /api/profile/picture (multipart)
         → Server: validate, compress to 500x500px, store
         → Response: 200 with imageUrl
         → Update User.profilePictureUrl = imageUrl
     → PUT /api/profile (JSON body)
         → Server: validate, update User table
         → Response: 200 with updated profile
     → Update Riverpod: userProfileProvider.invalidate()
     → Show success toast: "Profile saved!"
     → Pop back to ProfileViewScreen
     → ProfileViewScreen rebuilds with new data

6. VIEW OTHER USER'S PROFILE
   Search → Select result
     → ProfileViewScreen(userId: selectedUserId, isOwnProfile: false)
       → Not own profile → hide Edit button
       → Fetch other user's profile
       → If isPrivateProfile & not contact → show lock + "Profile is private"
       → Otherwise show profile info

7. PULL TO REFRESH
   ProfileViewScreen
     → Manual refresh gesture
       → userProfileProvider.refresh()
       → Bypass cache, fetch fresh profile from backend
       → Re-display with latest data
```

---

## Database Schema (Backend)

**User Table Updates**:
```sql
ALTER TABLE "user" ADD COLUMN "profile_picture_url" TEXT NULL;
ALTER TABLE "user" ADD COLUMN "about_me" VARCHAR(500) NULL DEFAULT '';
ALTER TABLE "user" ADD COLUMN "is_default_profile_picture" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "user" ADD COLUMN "is_private_profile" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "user" ADD COLUMN "profile_updated_at" TIMESTAMP NULL;
```

**ProfileImage Table**:
```sql
CREATE TABLE "profile_image" (
  "image_id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  "image_url" TEXT NOT NULL,
  "file_size" BIGINT NOT NULL,
  "format" VARCHAR(10) NOT NULL CHECK (format IN ('JPEG', 'PNG')),
  "uploaded_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" TIMESTAMP NULL,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_profile_image_user_id ON "profile_image"("user_id");
CREATE INDEX idx_profile_image_active ON "profile_image"("deleted_at") 
  WHERE "deleted_at" IS NULL;
```

---

## Dependency Summary

**Frontend**:
- riverpod 2.4.0 (state management)
- image_picker 1.0.0 (image selection)
- image ^4.0.0 (image validation & processing)
- flutter_secure_storage 9.0.0 (secure local cache)
- dio ^5.0.0 (HTTP client with multipart support)

**Backend**:
- serverpod (HTTP server + WebSocket)
- postgres (Database driver)
- image (image processing for compression)

---

*Data Model Complete - Ready for quickstart.md and API implementation*
