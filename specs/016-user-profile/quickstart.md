# Developer Quickstart: User Profile System

**Phase**: 1 - Design  
**Updated**: March 13, 2026  
**Target**: Flutter frontend + Dart backend developers

---

## Quick Overview

This guide helps developers get started implementing the User Profile System feature. The feature allows users to view/edit their profile with picture upload, username, bio, and privacy controls.

**Feature Scope**: 2-3 week implementation for full feature  
**Complexity**: Medium (involves image handling, form state, API integration)  
**Dependencies**: image_picker, Riverpod, HTTP/multipart upload

---

## File Structure

```
frontend/lib/features/profile/
├── models/
│   ├── user_profile.dart          ← Core data model
│   └── validation_error.dart      ← Error enum
├── screens/
│   ├── profile_view_screen.dart   ← Already exists, enhance
│   └── profile_edit_screen.dart   ← Enhance with full features
├── providers/
│   ├── user_profile_provider.dart ← Already exists, enhance
│   └── profile_form_state_provider.dart ← CREATE NEW
├── services/
│   └── profile_api_service.dart   ← CREATE NEW (HTTP client)
└── widgets/
    ├── profile_picture_widget.dart    ← CREATE NEW
    └── image_upload_widget.dart       ← CREATE NEW

backend/lib/src/
├── endpoints/
│   └── profile_endpoint.dart      ← CREATE/ENHANCE
├── services/
│   └── profile_service.dart       ← CREATE NEW
└── models/
    ├── user_profile.dart          ← Enhance
    └── profile_image.dart         ← CREATE NEW
```

---

## Implementation Checklist

### Phase 1A: Data Models & API Contract (Days 1-2)

- [ ] **Backend**:
  - [ ] Update User model with profile fields (aboutMe, profilePictureUrl, isPrivateProfile, etc.)
  - [ ] Create ProfileImage model for image metadata
  - [ ] Create database migrations for User + ProfileImage tables
  - [ ] Implement ProfileService business logic (fetch, update, delete profile)

- [ ] **Frontend**:
  - [ ] Create data models (UserProfileState, ProfileFormState, ValidationError)
  - [ ] Update User model in app with profile fields
  - [ ] Define API response types for Type Safety

---

### Phase 1B: Backend API Endpoints (Days 2-3)

- [ ] **Implement 4 REST endpoints**:
  - [ ] `GET /api/profile/:userId` - Fetch user profile
  - [ ] `PUT /api/profile` - Update text fields + privacy
  - [ ] `POST /api/profile/picture` - Upload image (multipart)
  - [ ] `DELETE /api/profile/picture` - Remove custom image

- [ ] **Validation & Error Handling**:
  - [ ] Validate username (3-32 chars, alphanumeric+underscore+hyphen)
  - [ ] Validate bio (0-500 chars)
  - [ ] Validate image (format, size, dimensions)
  - [ ] Return appropriate HTTP codes (400, 413, 404, 401)
  - [ ] Image compression to 500x500px on server

---

### Phase 1C: Frontend HTTP Client (Days 3-4)

- [ ] **Create ProfileApiService**:
  - [ ] `fetchProfile(userId)` - HTTP GET
  - [ ] `updateProfile(fieldUpdates)` - HTTP PUT
  - [ ] `uploadProfileImage(imageFile)` - HTTP POST multipart
  - [ ] `deleteProfileImage()` - HTTP DELETE
  - [ ] Error handling & retry logic

- [ ] **Type Safety**:
  - [ ] Serialize/deserialize profile response JSON
  - [ ] Handle network timeouts and errors
  - [ ] Log requests/responses for debugging

---

### Phase 2A: Form State Management with Riverpod (Days 4-5)

- [ ] **Create ProfileFormStateNotifier**:
  - [ ] Getters for username, bio, pendingImage, isPrivate, isDirty
  - [ ] Methods: updateUsername(), updateBio(), setImage(), removeImage(), togglePrivacy()
  - [ ] Method: resetForm() - revert to original values
  - [ ] Method: validate() - check all fields + return ValidationError
  - [ ] Method: save() - call API, handle async, mark isDirty=false on success

- [ ] **Create ProfileFormStateProvider**:
  - [ ] StateNotifierProvider wrapping ProfileFormStateNotifier
  - [ ] Initialize with current user profile data
  - [ ] Watch in UI for form state changes

- [ ] **Enhance UserProfileProvider**:
  - [ ] Add method setProfile(profile) for optimistic updates
  - [ ] Support cache invalidation after save
  - [ ] Handle refresh on pull gesture

---

### Phase 2B: UI Components (Days 5-7)

#### ProfileViewScreen Enhancements:
- [ ] Display profile picture (120x120 circular, or default avatar)
- [ ] Display username (non-editable)
- [ ] Display about me text (with "No bio added yet" placeholder)
- [ ] Display privacy indicator (lock icon if private)
- [ ] Show Edit button (own profile only)
- [ ] Loading skeleton while fetching
- [ ] Error state with retry button
- [ ] Pull-to-refresh gesture

#### ProfileEditScreen Implementation:
- [ ] Text input: username (3-32 chars, counter, live validation)
- [ ] Text input: about me (0-500 chars, counter, live validation)
- [ ] Image upload widget with gallery/camera options
- [ ] Remove picture button (conditional, with confirmation)
- [ ] Privacy toggle switch (public/private)
- [ ] Save button (disabled until isDirty=true)
- [ ] Cancel button (reverts changes)
- [ ] Inline error messages under each field
- [ ] Success toast on save
- [ ] Loading spinner during upload

#### Image Upload Widget:
- [ ] Square image preview (150x150 minimum)
- [ ] Camera icon button
- [ ] Gallery icon button
- [ ] Remove icon button (if custom image)
- [ ] Validation error display (format, size, dimensions)
- [ ] Loading indicator during upload progress

---

### Phase 2C: Image Handling & Validation (Days 7-8)

- [ ] **Client-side Validation** (in ProfileEditScreen or utility):
  - [ ] Check format: must be JPEG or PNG (use file extension or image package decode)
  - [ ] Check size: use file.lengthSync() ≤ 5,242,880 bytes
  - [ ] Check dimensions: use `image` package to decode → validate width/height
  - [ ] Return specific error message for each failure type

- [ ] **Image Upload Flow**:
  - [ ] User selects image → validate locally
  - [ ] Show error and allow retry if invalid
  - [ ] POST to /api/profile/picture with multipart form-data
  - [ ] Show progress indicator during upload
  - [ ] On 200 response: optimistic update (display new image immediately)
  - [ ] On error response: show error message, allow retry

- [ ] **Image Picker Integration**:
  - [ ] Request runtime permissions (gallery, camera)
  - [ ] Handle permission denial gracefully
  - [ ] Open gallery on gallery button tap
  - [ ] Open camera on camera button tap

---

### Phase 2D: Testing (Days 8-9)

- [ ] **Unit Tests**:
  - [ ] ProfileFormStateNotifier: validate(), resetForm(), isDirty transitions
  - [ ] Validation helpers: username, bio, image validators
  - [ ] API mock responses: success, error codes, timeout

- [ ] **Widget Tests**:
  - [ ] ProfileViewScreen rendering: profile data displayed correctly
  - [ ] ProfileEditScreen: form fields render with pre-populated values
  - [ ] ProfileEditScreen: Save button disabled/enabled based on isDirty
  - [ ] ImageUploadWidget: preview displays, buttons respond to taps

- [ ] **Integration Tests**:
  - [ ] Full flow: Edit screen → change fields → upload image → save → profile updated
  - [ ] Error handling: Network error → retry → success
  - [ ] Validation: Invalid image → error message → fix → retry → success

---

### Phase 2E: Polish & Edge Cases (Days 9-10)

- [ ] **Edge Cases**:
  - [ ] User with no custom picture (show default avatar)
  - [ ] User with empty bio (show placeholder)
  - [ ] Form changes preserved during validation errors
  - [ ] Network timeout during image upload (show retry)
  - [ ] Rapid successive uploads (only latest kept)
  - [ ] Permission denied for camera/gallery (show error)

- [ ] **Performance**:
  - [ ] Profile loads within 500ms
  - [ ] Images display within 2 seconds
  - [ ] Cache profile for 5 minutes
  - [ ] Lazy-load large images

- [ ] **Accessibility**:
  - [ ] Semantic labels for buttons (camera, gallery, remove)
  - [ ] Form field labels and error messages announced
  - [ ] Touch targets minimum 48x48 dp
  - [ ] Color contrast for text and icons

---

## Key Code Patterns

### Form State with Riverpod

```dart
// providers/profile_form_state_provider.dart
final profileFormStateProvider = StateNotifierProvider<
  ProfileFormStateNotifier,
  ProfileFormState
>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) => ProfileFormStateNotifier(profile),
    loading: () => ProfileFormStateNotifier.loading(),
    error: (err, _) => ProfileFormStateNotifier.error(err),
  );
});

class ProfileFormStateNotifier extends StateNotifier<ProfileFormState> {
  ProfileFormStateNotifier(UserProfile profile)
    : super(ProfileFormState.fromProfile(profile));
  
  void updateUsername(String value) {
    state = state.copyWith(
      username: value,
      isDirty: value != state.originalUsername || /* other fields */,
    );
  }
  
  Future<void> save() async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = await profileApi.updateProfile(...);
      state = state.copyWith(
        isLoading: false,
        isDirty: false,
        originalUsername: updated.username, // Reset original for next edit
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}
```

### Client-side Image Validation

```dart
// services/image_validator.dart
Future<ValidationError?> validateImage(File imageFile) async {
  // Check format
  final fileExt = imageFile.path.split('.').last.toLowerCase();
  if (!['jpg', 'jpeg', 'png'].contains(fileExt)) {
    return ValidationError.imageFormatInvalid;
  }
  
  // Check size
  final sizeBytes = await imageFile.length();
  if (sizeBytes > 5 * 1024 * 1024) {
    return ValidationError.imageTooLarge;
  }
  
  // Check dimensions
  final bytes = await imageFile.readAsBytes();
  final image = decodeImage(bytes);
  if (image == null || image.width < 100 || image.height < 100 ||
      image.width > 5000 || image.height > 5000) {
    return ValidationError.imageDimensionsInvalid;
  }
  
  return null; // valid
}
```

### Optimistic Image Update

```dart
// After successful upload response
Future<void> uploadImage(File imageFile) async {
  final validation = await validateImage(imageFile);
  if (validation != null) {
    // show error
    return;
  }
  
  try {
    final response = await profileApi.uploadImage(imageFile);
    
    // OPTIMISTIC: Update immediately with new URL from response
    state = state.copyWith(pendingImage: null);
    ref.read(userProfileProvider.notifier).setProfile(
      state.copyWith(profilePictureUrl: response.imageUrl),
    );
    
    // Image displays immediately without waiting for re-fetch
  } catch (e) {
    // show error, allow retry
  }
}
```

---

## Testing Examples

### Unit Test: Form Validation

```dart
test('username validation', () {
  final state = ProfileFormState.empty();
  
  expect(validateUsername('a'), ValidationError.invalidUsername); // too short
  expect(validateUsername('alice123'), null); // valid
  expect(validateUsername('alice' * 10), ValidationError.invalidUsername); // too long
  expect(validateUsername('alice@domain'), ValidationError.invalidUsername); // invalid chars
});
```

### Widget Test: ProfileEditScreen

```dart
testWidgets('Save button disabled until changes', (tester) async {
  await tester.pumpWidget(testApp);
  
  final saveButton = find.byKey(Key('save_button'));
  expect(tester.widget<ElevatedButton>(saveButton).enabled, false);
  
  // Change username
  await tester.enterText(find.byKey(Key('username_field')), 'new_name');
  await tester.pumpWidget(testApp);
  
  expect(tester.widget<ElevatedButton>(saveButton).enabled, true);
});
```

---

## Deployment Checklist

Before merging to main:

- [ ] All unit tests passing
- [ ] All widget tests passing  
- [ ] Integration test passing (full edit flow)
- [ ] Android APK builds successfully
- [ ] Backend endpoints tested with curl/Postman
- [ ] Docker compose starts backend cleanly
- [ ] Profile displays within 500ms
- [ ] Images upload within 2 seconds
- [ ] Code review approved (Constitution Check verified)
- [ ] Performance profiling: memory usage reasonable
- [ ] No hardcoded credentials or debug logs

---

## Debugging Tips

### Profile not displaying:
- Check userProfileProvider is watching correctly
- Verify API response format matches UserProfileState
- Check network tab in DevTools for API errors
- Use debugPrint(ref.watch(userProfileProvider)) to inspect state

### Image upload failing:
- Verify image_picker permissions granted (check AndroidManifest.xml, Info.plist)
- Check file size with `file.lengthSync()`
- Verify image format with `image` package decode
- Check HTTP response code and error message from backend

### Form not dirty after changes:
- Verify isDirty logic compares current vs original values
- Check TextEditingController values sync with Riverpod state
- Debug: print isDirty value after each field change

### Images not displaying after upload:
- Check imageUrl returned from API is valid HTTPS URL
- Verify CachedNetworkImage or Image widget can load the URL
- Check CORS headers on CDN/backend
- Verify image compression completed on server (500x500px)

---

## References

- [Flutter image_picker docs](https://pub.dev/packages/image_picker)
- [Riverpod docs](https://riverpod.dev)
- [Flutter testing guide](https://flutter.dev/docs/testing)
- [data-model.md](data-model.md) - Full data contracts
- [research.md](research.md) - Technical decisions and rationale

---

*Ready to start implementation! Begin with Phase 1A (Day 1-2): Create data models and migrations.*
