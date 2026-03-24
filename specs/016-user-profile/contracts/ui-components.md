# UI Component Contracts: User Profile System

**Version**: 1.0  
**Status**: Approved  
**Date**: March 13, 2026  
**Platform**: Flutter (Android/iOS)

---

## Component 1: ProfileViewScreen

### Purpose
Display user profile information in read-only mode. Shows profile picture, username, bio, and privacy status. Displays appropriate buttons based on whether user is viewing own profile or another user's.

### Props/Parameters
```dart
class ProfileViewScreenProps {
  final String userId;              // Whose profile to display
  final bool isOwnProfile;          // Determines UI variations (edit button, etc.)
  final User? currentUser;          // Optional: pre-loaded user data (optimization)
}
```

### State Management
```dart
// Watch profile data from Riverpod
final profile = ref.watch(userProfileProvider.select((p) => p.when(
  data: (user) => user,
  loading: () => null,
  error: (_, __) => null,
)));

// Manual refresh trigger
onRefresh: () => ref.refresh(userProfileProvider);
```

### Visual Layout

```
┌─────────────────────────────────────┐
│  [←]  Profile                [⋮]   │  Header with back button
├─────────────────────────────────────┤
│                                     │
│        [Profile Pic]                │  Profile picture: 120x120, circular
│                                     │  Shows default avatar if no custom image
├─────────────────────────────────────┤
│  alice_wonder                       │  Username: Bold, large
│  ══════════════════                 │
│                                     │
│  Coffee ☕ and books 📚            │  Bio: Wrapped text, or placeholder
│                                     │
│  [🔒]  Private Profile              │  Privacy badge if private
├─────────────────────────────────────┤
│  [Edit Profile]                     │  Own profile only
│  [Message]    [Add Friend]          │  Other profiles (future)
├─────────────────────────────────────┤
```

### Display Elements

| Element | Type | Notes |
|---------|------|-------|
| Profile Picture | CircleAvatar | 120x120px, default avatar if null |
| Username | Text (PascalCase + BoldFont) | Read-only, non-editable |
| About Me | Text (body1) | Multi-line, word-wrapped, empty-friendly |
| Privacy Badge | Icon + Text | Lock icon + "Private Profile" if private |
| Edit Button | ElevatedButton | Own profile only |
| Message Button | TextButton | Other profiles (future) |
| Add Friend Button | TextButton | Other profiles (future) |

### States

**Loading State**:
- Skeleton loaders for picture, username, bio
- Placeholder avatar
- Height maintained for smooth layout

**Error State**:
- Error message: "Failed to load profile"
- [Retry] button
- Fallback text

**Empty Bio State**:
- Placeholder text: "No bio added yet" (gray, italicized)

**Private Profile State** (other user's profile):
- Shows lock icon + "Private Profile"
- Shows limited info based on permissions (future)

### User Interactions

| Action | Behavior |
|--------|----------|
| Tap Edit button | Navigate to ProfileEditScreen with current profile data |
| Tap Message button | Show message composer (future) |
| Pull to refresh | Invalidate cache, fetch fresh profile from backend |
| Tap profile picture | Show expanded image (future) |
| Long-press username | Copy username to clipboard (future) |

### API Calls

**On Mount**:
- Fetch profile from `userProfileProvider`
- Use passed `currentUser` as optimization if available
- Show loading skeleton while fetching

**On Pull Refresh**:
- Call `ref.refresh(userProfileProvider)`
- Force bypass cache, fetch from backend
- Show loading indicator during refresh
- Update display with new data

### Performance Requirements
- First paint: 300ms (use pre-loaded currentUser data)
- Profile loads completely: 500ms
- Pull to refresh: 1-2 seconds
- No scroll jank (keep 60fps)

### Accessibility
- Semantic labels for buttons (e.g., "Edit your profile")
- Image alt text (e.g., "alice_wonder's profile picture")
- High color contrast for text (4.5:1 WCAG AA)
- Touch targets minimum 48x48 dp

### Platform Variations
- **Android**: MD3 design, Material buttons
- **iOS**: Cupertino-style components where applicable
- **Web**: Responsive to 600-1200px viewport

---

## Component 2: ProfileEditScreen

### Purpose
Allow user to edit their profile information: username, bio, profile picture, and privacy settings. Manages form state with validation and provides visual feedback.

### Props/Parameters
```dart
class ProfileEditScreenProps {
  final User currentUserProfile;    // Initial values for form
}
```

### State Management
```dart
// Watch form state from Riverpod
final formState = ref.watch(profileFormStateProvider);

// Methods: updateUsername, updateBio, setImage, removeImage, togglePrivacy, save, reset
ref.read(profileFormStateProvider.notifier).updateUsername(value);
```

### Visual Layout

```
┌──────────────────────────────────────┐
│  [←]  Edit Profile              [✓] │  Header with back & save buttons
├──────────────────────────────────────┤
│                                      │
│        [Profile Pic] [Camera] [X]    │  Picture with edit overlay
│           (150x150)                  │
├──────────────────────────────────────┤
│  Username                            │  Label
│  [alice_wonder        ] 15/32 chars  │  Text field with counter
│  Only letters, numbers, _ and -      │  Helper text
│                                      │
│  About Me                            │  Label
│  [Coffee ☕ and books 📚  ] 25/500  │  Multi-line text area with counter
│  Tell us about yourself              │  Helper text
│                                      │
│  [🔒] Private Profile                │
│       [○────────●]                   │  Toggle switch
│  Only contacts can see your profile  │  Description (future)
├──────────────────────────────────────┤
│  [← Cancel]              [Save →]    │  Footer buttons
└──────────────────────────────────────┘
```

### Form Fields

#### Username Field
```dart
TextField(
  controller: _usernameController,
  label: "Username",
  maxLength: 32,
  counter: "15/32",
  helperText: "Only letters, numbers, _ and -",
  onChanged: (value) => formUpdate(),
)
```
- Pre-populated with current username
- Max 32 characters (with counter)
- Real-time character count
- Error message if validation fails: "Username: 3-32 chars, letters/numbers/underscore/hyphen"

#### About Me Field
```dart
TextField(
  controller: _bioController,
  label: "About Me",
  maxLength: 500,
  minLines: 3,
  maxLines: 5,
  counter: "25/500",
  helperText: "Tell us about yourself",
  onChanged: (value) => formUpdate(),
)
```
- Pre-populated with current bio
- Max 500 characters (with counter)
- Multi-line (3-5 lines expandable)
- Real-time character count
- Error message if too long: "Bio cannot exceed 500 characters"

#### Privacy Toggle
```dart
SwitchListTile(
  title: "Private Profile",
  subtitle: "Only contacts can see your profile",
  value: formState.isPrivateProfile,
  onChanged: (value) => togglePrivacy(value),
)
```
- Toggle between public/private
- Description text explaining impact
- Default: false (public)

### Image Upload Widget (Embedded)

```
        [Profile Pic] 
     [Camera] [Gallery]        ← Buttons on tap override
```

- Display current profile picture (120x120 circular)
- Camera icon → open camera (take new photo)
- Gallery icon → open gallery (select existing photo)
- If custom image exists: Remove icon (×) to delete
- Tap on picture opens image picker
- Overlay text: "Change picture"

### States & Transitions

| From | Action | To | UI Change |
|------|--------|-----|-----------|
| Empty | Type username | Dirty | Save button enabled |
| Dirty | Delete text | Clean | Save button disabled |
| Clean | Tap camera | Loading | Show spinner on image |
| Loading | Image selected | Validating | Show error or preview |
| Validating | Invalid format | Error | Show "Only JPEG/PNG..." error |
| Error | Select new image | Validating | Allow retry |
| Valid | Submit form | Saving | Disable all buttons, show spinner |
| Saving | Success | Saved | Toast "Profile saved!", pop screen |
| Saving | Error | Error | Show retry button |

### Save Button Behavior
- **Disabled** (gray) until isDirty = true (e.g., at least one field changed)
- **Enabled** (blue) when changes detected
- **Loading** (spinner) during form submission
- **Disabled** after success, then pop screen automatically

### Cancel Button Behavior
- Always enabled
- Tap → discard all changes → pop screen
- Optional confirmation dialog: "Discard changes?"

### Error Handling

**Validation Errors** (inline, real-time):
```
Username field:     ← Username must be 3-32 characters
                    Error color: red/accent

Bio field:          ← Bio cannot exceed 500 characters
                    Error color: red/accent

Image upload:       ← Only JPEG and PNG formats supported
                    Error type badge under image
```

**Network Errors** (bottom sheet or banner):
```
┌─────────────────────────────────┐
│ ✗ Unable to save profile        │
│   Check your connection         │
│              [Retry]            │
└─────────────────────────────────┘
```

**Success Notification** (toast):
```
✓ Profile saved!
```

### Image Upload Flow

1. User taps picture → opens ImagePickerWidget
2. User selects image from gallery or camera
3. Image decoded and validated (format, size, dimensions)
4. If invalid: show error message inline, allow retry
5. If valid: show preview
6. User confirms → pendingImage set in form state
7. Form isDirty = true → Save button enabled
8. User taps Save → triggers full profile save
9. Image uploaded via multipart POST to /api/profile/picture
10. On 200 response: optimistic update (show imageUrl immediately)
11. Text fields saved via PUT to /api/profile
12. Both complete → show success toast + pop screen

### Performance Requirements
- Form load: <200ms (pre-populate from passed data)
- Character counter updates: <50ms (debounced)
- Image selection: <500ms (image picker plugin)
- Image validation: <500ms (image package decode)
- Form submission: <2s for image + text fields

### Accessibility
- Form field labels associated with inputs
- Error messages announced by screen reader
- Button labels descriptive (not just "Submit")
- Toggle switch has accessible label
- Image alt text for selected images
- Touch targets minimum 48x48 dp
- Focus order logical (username → bio → image → privacy → buttons)

---

## Component 3: ImageUploadWidget

### Purpose
Encapsulated image selection and validation widget. Used in ProfileEditScreen and reusable for other image uploads.

### Props/Parameters
```dart
class ImageUploadProps {
  final File? currentImage;         // null = show default, File = show current
  final VoidCallback onImageSelected;
  final VoidCallback onImageRemoved;
  final String? errorMessage;       // displays validation error
  final bool isLoading;
  final String errorCode;           // specific error for styling
}
```

### Visual Layout

```
  [Current/Default Image]
       150x150 px
  [Overlay on Hover]
     "Change picture"
  
  [Camera 📷]  [Gallery 🖼]  [Remove ✕]   ← Buttons (if custom image)
     (conditional: only if custom exists)
```

### Display Modes

**Valid State** (no error):
- Show selected image preview (150x150, square)
- Show camera, gallery, and remove buttons (if custom)
- No error text

**Error State** (validation failure):
- Show selected image preview (150x150, square)  
- Show red border around image
- Show error message below: "Only JPEG and PNG formats are supported"
- Show retry/clear buttons

**Loading State** (during upload):
- Dim image (opacity 0.5)
- Show centered progress spinner
- Disable all buttons

**Empty State** (no image selected):
- Show default avatar (150x150, square)
- Show camera + gallery buttons
- Optional: "Add picture" text below

### Buttons

| Button | Trigger | Behavior |
|--------|---------|----------|
| Camera | Tap | Open device camera → capture photo → validate → onImageSelected |
| Gallery | Tap | Open photo gallery → select image → validate → onImageSelected |
| Remove | Tap | Delete custom image → onImageRemoved → show default avatar |

### Validation Flow

```
User taps Camera/Gallery
   ↓
Image picker returns File
   ↓
validateImage(file):
  - Check format (JPEG/PNG)
  - Check size (≤5MB)
  - Check dimensions (100-5000px)
   ↓
[Valid] → onImageSelected(file) → Show preview
   ↓
[Invalid] → errorMessage = specific error → Show error badge
   ↓
User can tap Remove to clear error or Camera/Gallery to retry
```

### Error Messages

| Validation | Error Message |
|-----------|----------------|
| Wrong format | "Only JPEG and PNG formats are supported" |
| Too large | "File must be smaller than 5MB" |
| Wrong dimensions | "Image must be between 100x100 and 5000x5000 pixels" |
| Corrupted file | "Could not process image, please try again" |

---

## Component 4: ProfilePictureWidget (Display Only)

### Purpose
Reusable widget for displaying profile pictures across app (profile, chat preview, search results). Handles default avatar fallback and image loading states.

### Props/Parameters
```dart
class ProfilePictureProps {
  final String? imageUrl;           // null = show default
  final String? displayName;        // For default avatar initials
  final double size;                // 48, 80, 120 px
  final VoidCallback? onTap;        // Show expanded image (optional)
}
```

### Display Modes

**Default Avatar**:
- Initials of displayName (e.g., "AW" for "alice_wonder")
- Circular background color (deterministic from username hash)
- Backup: Generic user icon

**Custom Picture**:
- CachedNetworkImage for efficient loading
- Circular clip
- Placeholder while loading
- Error fallback to default avatar
- Optional tap to expand

### Size Variants
- Small (48px) - chat list, search results
- Medium (80px) - message composer
- Large (120px) - profile header

---

## State Model Contracts (Riverpod)

```dart
// Provider: userProfileProvider (FutureProvider)
// Fetches user profile from backend, caches for 5 minutes
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  // Returns: UserProfile with all fields
  // States: AsyncValue.loading() → .data(profile) or .error(error)
});

// Provider: profileFormStateProvider (StateNotifierProvider)
// Manages edit form state
final profileFormStateProvider = StateNotifierProvider<
  ProfileFormStateNotifier,
  ProfileFormState
>((ref) {
  // Returns: ProfileFormState with current form values
  // Notifier methods: updateUsername, updateBio, setImage, removeImage,
  //                  togglePrivacy, save(), reset(), validate()
});
```

---

## Testing Contracts

```dart
testWidgets('ProfileViewScreen displays username', (tester) async {
  // Given: Profile loaded with username "alice_wonder"
  // When: Profile screen rendered
  // Then: Username displayed as bold text
  expect(find.text('alice_wonder'), findsOneWidget);
});

testWidgets('Save button disabled until changes', (tester) async {
  // Given: Edit screen open with current profile
  // When: User hasn't made changes
  // Then: Save button disabled (gray)
  expect(saveButton.enabled, false);
});

testWidgets('Invalid image shows error message', (tester) async {
  // Given: User selects 6MB image
  // When: Upload validation runs
  // Then: Error message shows "File must be smaller than 5MB"
  expect(find.text('File must be smaller than 5MB'), findsOneWidget);
});
```

---

*UI Component Contracts Complete - Ready for frontend implementation*
