# Feature Specification: User Profile System

**Feature Branch**: `016-user-profile`  
**Created**: March 13, 2026  
**Status**: Complete  
**Specification Version**: 1.0

## Overview

Users can create and customize their profile with a picture, username, and bio. The profile is visible to other users in the messenger. Profile data persists and loads immediately after login. This feature provides a complete profile management system with image upload, validation, privacy controls, and a polished user experience.

## User Scenarios & Testing

### User Story 1: View My Profile (Priority: P1)

As a user, I want to see my profile information displayed immediately so I know what other users see about me.

**Why this priority**: Viewing one's own profile is the core feature that enables all other profile interactions. Without this, users cannot verify or edit their information.

**Independent Test**: User logs in → navigates to Profile tab → sees their username, bio, and profile picture displayed correctly within 500ms.

**Acceptance Scenarios**:

1. **Given** a user is logged in, **When** they navigate to the Profile tab, **Then** their profile displays with username, default/custom picture, and about me text
2. **Given** a user is viewing their own profile, **When** they scroll, **Then** all profile information remains visible and editable
3. **Given** a user has no custom profile picture, **When** they view their profile, **Then** a generic default avatar is displayed
4. **Given** a user has an empty about me bio, **When** they view their profile, **Then** placeholder text "No bio added yet" is displayed

---

### User Story 2: Edit My Profile Information (Priority: P1)

As a user, I want to edit my username and bio so my profile reflects my current information.

**Why this priority**: Profile editing is essential for users to customize their appearance. Without this, profiles would be static and unusable.

**Independent Test**: User opens profile edit screen → modifies username and bio → saves changes → logs out/in → verifies changes persist.

**Acceptance Scenarios**:

1. **Given** I'm viewing my profile, **When** I tap Edit Profile, **Then** I enter edit mode with pre-populated username and about me fields
2. **Given** I'm in edit mode, **When** I change my username to "NewUsername123", **Then** the field updates and save button becomes enabled
3. **Given** I've made changes, **When** I tap Save, **Then** changes are saved to backend and I see a success confirmation
4. **Given** changes are saved, **When** I navigate away and return, **Then** my profile displays updated information
5. **Given** I'm in edit mode, **When** I tap Cancel, **Then** changes are discarded and I return to view mode

---

### User Story 3: Upload Profile Picture (Priority: P1)

As a user, I want to upload a custom profile picture so other users can recognize me.

**Why this priority**: Profile pictures are a core visual identity element in any messenger. This is critical for user recognition and engagement.

**Independent Test**: User in edit mode → selects JPEG/PNG image ≤5MB → upload succeeds → picture displays on profile → persists across sessions.

**Acceptance Scenarios**:

1. **Given** I'm in edit mode, **When** I tap "Upload Picture", **Then** image picker opens showing gallery and camera options
2. **Given** I select a valid JPEG image ≤5MB from gallery, **When** upload completes, **Then** new picture displays on profile immediately
3. **Given** I select a valid PNG image, **When** upload completes, **Then** picture displays and replaces any previous image
4. **Given** I've uploaded a custom picture, **When** I refresh the app, **Then** my custom picture persists
5. **Given** a picture is uploaded, **When** other users search for me, **Then** they see my custom picture on my profile

---

### User Story 4: Validate Image Format & Size (Priority: P2)

As a user, I want the system to validate my image before upload so I know what formats are supported and why my upload failed.

**Why this priority**: Proper validation prevents wasted time uploading invalid images and provides clear user guidance. P2 because while essential, it's secondary to successful uploads working.

**Independent Test**: User attempts to upload GIF (rejected), BMP (rejected), 6MB image (rejected) → receives specific error messages → can retry with valid file.

**Acceptance Scenarios**:

1. **Given** I select a GIF image, **When** I attempt upload, **Then** error displays: "Only JPEG and PNG formats are supported"
2. **Given** I select a 6MB image, **When** I attempt upload, **Then** error displays: "File must be smaller than 5MB"
3. **Given** an error occurred, **When** I see the error message, **Then** form remains populated and I can try again
4. **Given** I select an image with wrong dimensions, **When** upload fails, **Then** error displays: "Image must be between 100x100 and 5000x5000 pixels"
5. **Given** multiple validation errors are possible, **When** user selects invalid file, **Then** the most relevant error is shown first

---

### User Story 5: Remove Picture & Revert to Default (Priority: P2)

As a user, I want to remove my custom picture and revert to the default so I can reset my profile appearance.

**Why this priority**: Users should have full control including the ability to undo custom pictures. P2 because it's a secondary interaction.

**Independent Test**: User has custom picture → edit mode → tap "Remove Picture" → default avatar displays → persists across sessions.

**Acceptance Scenarios**:

1. **Given** I have a custom profile picture, **When** I enter edit mode, **Then** a "Remove Picture" button is visible
2. **Given** I tap "Remove Picture", **When** confirmation is optional, **Then** custom picture is deleted
3. **Given** picture is removed, **When** I save changes, **Then** backend confirms deletion
4. **Given** picture is removed, **When** I view my profile, **Then** generic default avatar displays
5. **Given** I removed a picture, **When** I log out/in, **Then** default picture persists

---

### User Story 6: Privacy Controls (Priority: P3)

As a user, I want to toggle my profile between public and private so I can control who sees my information.

**Why this priority**: Privacy is important but can be implemented after core profile functionality. P3 allows MVP to launch without privacy restrictions initially.

**Independent Test**: Edit mode → toggle "Private Profile" switch → save → verify setting persists across sessions.

**Acceptance Scenarios**:

1. **Given** I'm in edit mode, **When** I view the profile settings, **Then** a "Private Profile" toggle switch is visible
2. **Given** I toggle the switch to ON, **When** I save, **Then** setting is saved and persists
3. **Given** my profile is private, **When** I view my profile, **Then** a lock icon shows "Private Profile" indicator
4. **Given** my profile is private, **When** other users search for me, **Then** they cannot view my full profile (future implementation: contacts-only visibility)
5. **Given** I toggle back to public, **When** I save, **Then** all users can see my profile again

---

### User Story 7: Search & View Other User Profiles (Priority: P2)

As a user, I want to search for other users and view their profiles so I can learn about them before messaging.

**Why this priority**: While profile viewing is critical, this relates more to search functionality (separate feature). P2 because search+profile intersection can launch in phase 2.

**Independent Test**: Search for user → tap search result → view their profile → see their picture, username, and bio.

**Acceptance Scenarios**:

1. **Given** I search for a user, **When** they appear in results, **Then** I can tap to view their profile
2. **Given** I view another user's profile, **When** profile loads, **Then** their picture, username, and bio are visible
3. **Given** another user has a private profile, **When** I view their profile, **Then** I see limited information based on privacy setting
4. **Given** I'm viewing another user, **When** their profile has no bio, **Then** placeholder text is shown gracefully

---

### Edge Cases

- **No bio edge case**: System handles empty "about me" gracefully with placeholder text
- **Large image edge case**: 5MB image at exactly 5MB is accepted; 5MB + 1 byte is rejected
- **Dimension boundary**: 100x100px accepted, 99x99px rejected; 5000x5000px accepted, 5001x5001px rejected
- **Concurrent edits**: User A and B both editing User C's profile simultaneously - last write wins (acceptable for MVP)
- **Network interruption during upload**: Connection lost mid-upload - retry mechanism preserves form state
- **Rapid successive uploads**: User clicks upload multiple times - only latest valid upload is kept, previous uploads ignored
- **After upload, before confirmation**: User closes app during upload confirmation - profile reverts to previous picture until upload retries
- **Very slow network**: Image upload takes >10 seconds - show progress indicator, allow cancel
- **Storage full**: Backend out of space - clear error message: "Unable to save image, try again later"
- **Null/special characters in username**: "Name; DROP TABLE" or "Name\n\n" - sanitized during input and trimmed
- **Very long email address displayed**: Email field very long - wrap or truncate appropriately in UI
- **Deleted user account**: If user deleted but search results cached - graceful error when viewing profile
- **Image orientation**: User uploads portrait-oriented 100x5000px image - accepted technically but should warn or auto-crop

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST display user profile with picture (default or custom), username, and "about me" bio on dedicated profile screen
- **FR-002**: System MUST allow authenticated users to edit their username (3-32 characters, alphanumeric + underscore)
- **FR-003**: System MUST allow editing of "about me" bio (0-500 characters, optional)
- **FR-004**: System MUST validate image uploads: JPEG/PNG format only, maximum 5MB file size
- **FR-005**: System MUST validate image dimensions: minimum 100x100px, maximum 5000x5000px
- **FR-006**: System MUST upload images to backend and store secure URLs
- **FR-007**: System MUST return image URL immediately after successful upload
- **FR-008**: System MUST compress/optimize images to 500x500px on server before storage
- **FR-009**: System MUST support removing custom picture and reverting to default avatar
- **FR-010**: System MUST persist profile changes to database immediately with confirmation
- **FR-011**: System MUST load profile data on app startup or when navigating to profile screen
- **FR-012**: System MUST make profile changes visible to other users within 2 seconds
- **FR-013**: System MUST allow users to toggle profile privacy (public/private)
- **FR-014**: System MUST display privacy status (public/private indicator) on profile view
- **FR-015**: System MUST allow default (public) privacy setting for newly created profiles
- **FR-016**: System MUST allow duplicate usernames (users identified by user ID, NOT username uniqueness)
- **FR-017**: System MUST display profile view in 500ms or less after navigation
- **FR-018**: System MUST provide Edit button on own profile only; other profiles show view-only interface
- **FR-019**: System MUST handle network errors with retry buttons while maintaining form state
- **FR-020**: System MUST show specific error messages for validation failures (format, size, dimensions)

### Error Handling Requirements

- **ER-001**: Format error: Display "Only JPEG and PNG formats are supported" (HTTP 400)
- **ER-002**: Size error: Display "File must be smaller than 5MB" (HTTP 413)
- **ER-003**: Dimension error: Display "Image must be between 100x100 and 5000x5000 pixels" (HTTP 400)
- **ER-004**: Network error: Show retry button, maintain form state, preserve user input
- **ER-005**: Database error: Display "Unable to process request", allow retry
- **ER-006**: Permission error (viewing others' profiles): Prevent editing, return HTTP 403 for API calls

### Validation Requirements

- **VR-001**: Username must be 3-32 characters after trimming whitespace
- **VR-002**: Username may contain: a-z, A-Z, 0-9, underscore (_), hyphen (-)
- **VR-003**: About me must not exceed 500 characters after trimming
- **VR-004**: Either username or about me can be submitted unchanged (both fields optional for editing)
- **VR-005**: Image file must be JPEG (.jpg/.jpeg) or PNG (.png) format
- **VR-006**: Image dimensions must be between 100x100 and 5000x5000 pixels (inclusive)
- **VR-007**: Image file size must not exceed 5MB (5,242,880 bytes)

### UI/UX Requirements

- **UXR-001**: Profile screen MUST be accessible via bottom navigation bar with person icon
- **UXR-002**: Edit button MUST only appear on own profile (not on viewed profiles)
- **UXR-003**: Upload button MUST offer both gallery and camera options
- **UXR-004**: Remove picture button MUST only show if custom image exists
- **UXR-005**: Save button MUST be disabled until changes are made (isDirty flag)
- **UXR-006**: Current field values MUST be pre-populated in edit form
- **UXR-007**: Success confirmation MUST display after save
- **UXR-008**: Form fields MUST maintain state during validation errors
- **UXR-009**: Privacy toggle MUST clearly indicate public/private status

---

## Key Entities

### User Profile Fields

```
- userId: string (Primary Key, user ID not changeable)
- username: string (3-32 chars, editable, duplicates allowed)
- email: string (from registration, not editable in profile)
- profilePictureUrl: string | null (URL to uploaded image, null = default)
- aboutMe: string (0-500 chars, editable, optional)
- isDefaultProfilePicture: boolean (true=using default, false=custom upload)
- isPrivateProfile: boolean (true=private, false=public, default: false)
- profileUpdatedAt: timestamp (last modification time)
- emailVerified: boolean (from auth, not editable)
- createdAt: timestamp (account creation time)
```

### Profile Image Entity

```
- imageId: string (Primary Key)
- userId: string (Foreign Key to User)
- imageUrl: string (secure URL to stored image)
- fileSize: number (bytes, for logging and analysis)
- format: string ("JPEG" | "PNG")
- uploadedAt: timestamp (when upload completed)
- isActive: boolean (soft delete support, true=active)
```

---

## Success Criteria

1. **User can view their profile** - Profile displays username, picture, and bio within 500ms of navigation with proper formatting
2. **User can edit profile information** - Username and bio changes save to backend and persist across app restarts
3. **Image upload works end-to-end** - Valid JPEG/PNG ≤5MB uploads successfully and displays immediately, persists across sessions
4. **Image validation prevents invalid uploads** - Unsupported formats and oversized files rejected with specific error messages per file type
5. **Default image displays first** - New users see default avatar immediately; only custom uploads change the image
6. **Profile visible to all users** - Any user can search for another user and view their profile (based on privacy settings)
7. **Form maintains state on error** - Upload failures don't clear form; user can correct and retry
8. **Privacy controls work** - Toggle between public/private persists and affects visibility (view logic in other features)
9. **Appropriate permissions enforced** - Users cannot edit others' profiles; API returns 403 for unauthorized attempts
10. **Performance targets met** - Profile loads in 500ms, image uploads complete in 2 seconds, changes visible to others within 2s

---

## Constraints & Assumptions

### Technical Assumptions
- Profile pictures stored on backend (file system or cloud storage service)
- Image compression/cropping handled automatically on server (no client-side pre-processing)
- Backend provides secure, permanent URLs for stored images
- JWT token authentication already in place; profile endpoints require valid token
- Database supports soft-delete pattern for profile images (isActive flag)
- Profile queries can be cached for performance (2-second visibility delay is acceptable)
- Username changes are allowed unlimited times (no immutability requirement)
- No audit trail required for username/bio changes (logging is nice-to-have)
- CDN or direct HTTP serving of profile images is acceptable

### Business Assumptions
- Usernames do NOT need global uniqueness (duplicate usernames allowed)
- Users identified primarily by user ID, not username
- Profile information is never truly deleted (maintained for chat history context)
- Profile visibility defaults to public (no restrictive privacy by default)
- Password and email address NOT editable via profile screen (separate features)
- Profiles visible between users without friend relationship requirement (open messenger)
- Username changes don't affect active chat conversations/messages (use user ID for references)
- Profile data relatively stable (not expected to change frequently)

### Product Assumptions
- Privacy = public/private toggle only (advanced controls like blocklists are future features)
- Private profiles visible only to contacts (implementation deferred to future release)
- No profile follow/unfollow system in MVP
- No profile verification badges or special indicators beyond privacy status
- Profile picture upload timing: user initiates, explicit save required (not auto-save)
- No profile preview before final upload (user sees result after save completes)

### Scope Boundaries
- ✅ IN SCOPE: View own profile, edit username/bio, upload image, remove image, privacy toggle
- ✅ IN SCOPE: View other users' profiles via search
- ❌ OUT OF SCOPE: Profile follow system
- ❌ OUT OF SCOPE: Advanced privacy (friends-only, blocklists)
- ❌ OUT OF SCOPE: Profile history/audit trail
- ❌ OUT OF SCOPE: Profile verification or special badges
- ❌ OUT OF SCOPE: Custom backgrounds/themes
- ❌ OUT OF SCOPE: Social features (bio links, contact info)

---

## Clarifications Resolved

✅ **Username Uniqueness**: Usernames do NOT need to be unique. Users are primarily identified by user ID. In chat contexts, display as "username" with user ID available for reference to prevent confusion.

✅ **Profile Visibility**: Users can toggle profile between public (visible to all) and private (visible to contacts only). Default is public. Privacy enforcement is primarily UI-based in MVP; advanced permission checks handled by backend API.

✅ **Image Processing**: Direct client upload, no client-side cropping/compression. Backend receives image and handles compression to 500x500px, optimization, and URL generation. Client receives final image URL immediately after upload completes.

✅ **Field Editing**: Both username and about me are optional fields. User can save profile with either/both unchanged. No "required field" validation beyond format checks.

✅ **Profile Loading**: Profile loads immediately on app startup from authentication data. Separate fetch for detailed profile info (including images) happens on navigation to profile screen, using cached data when available.

---

*Specification Complete - Ready for Planning Phase*
