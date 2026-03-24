# User Profile System

## Overview
Users can create and customize their profile with a picture, username, and bio. The profile is visible to other users in the messenger. Profile data persists and loads immediately after login.

## User Story
As a user, I want to view and edit my profile so that I can customize my appearance and share information with other users in the messenger.

## User Scenarios & Acceptance Testing

### Scenario 1: First Login - Default Profile
**Given** a user logs in for the first time  
**When** the app navigates to the profile screen  
**Then**:
- A default profile picture is displayed (generic avatar)
- Username field shows the username entered during registration
- "About me" text is empty
- Edit button is available and accessible

**Test**: New user logs in → profile screen shows default image + username + empty bio ✓

### Scenario 2: Edit Profile Information
**Given** a user is viewing their profile  
**When** they tap Edit and modify the username to "NewUsername123" and "About me" to "Hello world"  
**Then**:
- Changes are saved to the backend
- Profile refreshes and shows updated information
- Changes persist across app restarts and device relaunches
- User sees success confirmation message

**Test**: Edit fields → save → logout/login → data persists ✓

### Scenario 3: Upload Valid Profile Picture
**Given** a user is in edit mode  
**When** they select a JPEG or PNG image ≤5MB  
**Then**:
- Image is validated (format + size)
- Upload succeeds
- New profile picture displays immediately on profile screen
- Image persists across sessions

**Test**: Upload JPEG → display ✓, Upload PNG → display ✓, Upload 5MB → success ✓

### Scenario 4: Image Upload Validation - Format
**Given** a user attempts to upload a profile picture  
**When** they select an unsupported file format (GIF, BMP, WEBP, etc.)  
**Then**:
- Upload is rejected
- Error message displays: "Only JPEG and PNG formats are supported"
- No file is saved
- User can try again with correct format

**Test**: Upload GIF → error message ✓

### Scenario 5: Image Upload Validation - Size
**Given** a user attempts to upload a profile picture  
**When** they select an image >5MB  
**Then**:
- Upload is rejected
- Error message displays: "File must be smaller than 5MB"
- No file is saved
- User can try again with smaller file

**Test**: Upload 6MB image → error message ✓

### Scenario 6: Revert to Default Picture
**Given** a user has a custom profile picture  
**When** they tap "Remove picture" or equivalent in edit mode  
**Then**:
- Custom picture is deleted from backend
- Default profile picture displays again
- Change persists across app restarts

## Functional Requirements

### FR1: Profile Model
The profile must store and retrieve:
- User profile picture (URL to stored image file)
- Username (text, 3-32 characters)
- About me bio (text, 0-500 characters)
- Last updated timestamp
- Default image flag (true when using default, false when custom)

### FR2: View Profile Screen
- Display current profile picture (default or custom)
- Display username (non-editable in view mode)
- Display about me text
- Display privacy status (public/private indicator)
- Provide Edit button to enter edit mode (own profile only)
- If user's own profile: show Edit + Privacy toggle, If viewing other user: show Friend/Message buttons (or privacy message if profile hidden)

### FR3: Edit Profile Screen
- Text field for username (pre-populated, editable)
- Text field for about me (pre-populated, max 500 chars, editable)
- Image upload button to select new profile picture
- Remove/Delete picture button (if custom image exists)
- Save button (enabled only when changes made)
- Cancel button (discards unsaved changes)

### FR4: Profile Picture Upload
- Accept JPEG and PNG formats only
- Validate file size ≤5MB
- Validate image dimensions (minimum 100x100px, maximum 5000x5000px)
- Compress/optimize image before storage (target: 500x500px or similar)
- Store on backend with secure URL
- Return new image URL to client immediately

### FR5: Form Validation
- Username: 3-32 characters, alphanumeric + underscore allowed, trim whitespace
- Username uniqueness: Allow duplicate usernames (users identified by user ID, display as "username (ID)" in chat contexts)
- About me: 0-500 characters, trim whitespace
- Both fields are optional for editing (can save with either/both unchanged)

### FR6: Data Persistence
- Profile changes saved to backend database immediately
- Client receives confirmation before updating local state
- Profile loads on app startup (cached or fresh from backend)
- Changes visible to other users within 2 seconds

### FR7: Error Handling
- Network error: Show retry button, maintain form state
- Image validation error: Show specific error message (format or size), don't clear form
  - Format error message: "Only JPEG and PNG formats are supported" (HTTP 400)
  - Size error message: "File must be smaller than 5MB" (HTTP 413)
  - Dimension error message: "Image must be between 100x100 and 5000x5000 pixels" (HTTP 400)
- Database error: Show generic "Unable to process request" message, allow retry
- Permission error: Prevent editing others' profiles (show view-only interface), return HTTP 403 for API calls

## Success Criteria

1. **User can view their profile** - Profile screen displays all three fields (picture, username, about me) within 500ms of navigation
2. **User can edit profile information** - Changes to username/about me are saved and persist across app restarts
3. **Image upload works** - Valid JPEG/PNG images ≤5MB upload and display successfully within 2 seconds
4. **Image validation prevents invalid uploads** - Unsupported formats and oversized files are rejected with clear error messages
5. **Default image displays first** - New users see default profile picture immediately after registration
6. **Profile visible to all users** - Profile can be viewed by any user in messenger (search/chat context)

## Key Entities

### User (updated)
```
- userId: string (PK)
- username: string ✓ (already exists)
- email: string ✓ (already exists)
- profilePictureUrl: string (nullable, default null means use default image)
- aboutMe: string (default: "")
- isDefaultProfilePicture: boolean (default: true)
- updatedAt: timestamp
```

### Profile Image (new)
```
- imageId: string (PK)
- userId: string (FK to User)
- imageUrl: string
- fileSize: number (bytes)
- format: string (JPEG | PNG)
- uploadedAt: timestamp
- isActive: boolean (soft delete support)
```

### FR8: Privacy Controls
- Users can toggle profile visibility (public/private) in edit mode
- Public profiles: visible to all users in messenger
- Private profiles: visible only to friends or contacts (future implementation)
- Default: Public (all new profiles are public)
- Privacy setting persists across sessions

## Constraints & Assumptions

### Assumptions
- Profile pictures are stored on backend (file system or cloud storage)
- Image compression and cropping are automatic on server (direct client upload, no pre-processing)
- Username changes are allowed (no immutable requirement)
- Usernames do NOT need to be globally unique (duplicates allowed)
- About me is entirely optional and can be empty/cleared anytime
- Profiles are public by default (users can toggle to private)
- Profile updates require valid JWT token (already authenticated)

### Technical Constraints
- Max image file size: 5MB (before compression)
- Supported formats: JPEG (`.jpg`, `.jpeg`), PNG (`.png`)
- Image minimum dimensions: 100x100px (validation at upload)
- Image maximum dimensions: 5000x5000px (reasonable limit)
- Username length: 3-32 characters
- About me length: 0-500 characters
- Profile picture serving: CDN or direct URL from backend

## Clarifications Resolved

✅ **Username Uniqueness**: Allow duplicate usernames. Users are primarily identified by user ID. In chat contexts, display as "username (ID)" to prevent confusion.

✅ **Profile Visibility**: Users can toggle profile privacy. Default is public. Private profiles can be viewed only by contacts (future implementation scope).

✅ **Image Cropping**: Direct upload (no client-side cropping). Server handles compression and cropping to square format (500x500px). User sees final result after upload completes.
