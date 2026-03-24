# State Management Contracts: User Profile System

**Version**: 1.0  
**Framework**: Riverpod 2.4.0  
**Status**: Approved  
**Date**: March 13, 2026

---

## Provider Architecture

```
userProfileProvider (FutureProvider)
  ↓ (provides)
  UserProfile (data)
  ↓ (watched by)
  ProfileViewScreen & profileFormStateProvider
  
profileFormStateProvider (StateNotifierProvider)
  ↓ (watches)
  userProfileProvider (for initialization)
  ↓ (mutates)
  ProfileFormStateNotifier
  ↓ (watched by)
  ProfileEditScreen
```

---

## Provider 1: userProfileProvider

**Type**: `FutureProvider<UserProfile>`

**Purpose**: Fetch and cache user profile data from backend

**Declaration**:
```dart
final userProfileProvider = FutureProvider.family<UserProfile, String>((ref, userId) async {
  final apiService = ref.watch(profileApiServiceProvider);
  return await apiService.fetchProfile(userId);
});
```

**Caching Strategy**:
- Default Riverpod caching: 5-minute TTL (keep_alive default)
- Use `ref.refresh(userProfileProvider(userId))` to bypass cache
- Use `ref.watch(userProfileProvider(userId).select(...))` to select specific fields

**States**:
```dart
// AsyncValue.loading() - First fetch or manual refresh
// AsyncValue.data(UserProfile(...)) - Profile loaded successfully
// AsyncValue.error(Exception, StackTrace) - Network or parsing error
```

**Usage in UI**:
```dart
// In ConsumerWidget or ConsumerStatefulWidget
final profileAsync = ref.watch(userProfileProvider(userId));

profileAsync.when(
  loading: () => SkeletonLoader(),
  error: (error, stack) => ErrorWidget(error: error),
  data: (profile) => ProfileContent(profile: profile),
);

// Manual refresh
ElevatedButton(
  onPressed: () => ref.refresh(userProfileProvider(userId)),
  child: Text('Refresh'),
);
```

**API Integration**:
- Calls `GET /api/profile/{userId}`
- Headers: `Authorization: Bearer {token}`
- Returns: JSON parsed to UserProfile model
- Error handling: Maps HTTP status codes to exceptions

**Invalidation Triggers**:
- After successful profile update (PUT /api/profile)
- After successful image upload (POST /api/profile/picture)
- After successful image delete (DELETE /api/profile/picture)
- On manual refresh button press

---

## Provider 2: profileFormStateProvider

**Type**: `StateNotifierProvider<ProfileFormStateNotifier, ProfileFormState>`

**Purpose**: Manage editable profile form state with validation

**Declaration**:
```dart
final profileFormStateProvider = 
  StateNotifierProvider<ProfileFormStateNotifier, ProfileFormState>((ref) {
    final profileAsync = ref.watch(userProfileProvider(ref.watch(userIdProvider)));
    
    return profileAsync.when(
      loading: () => ProfileFormStateNotifier.loading(),
      error: (e, _) => ProfileFormStateNotifier.error(e),
      data: (profile) => ProfileFormStateNotifier(profile),
    );
  });
```

**State Definition**:
```dart
@freezed
class ProfileFormState with _$ProfileFormState {
  const factory ProfileFormState({
    // Current input values
    required String username,
    required String aboutMe,
    required File? pendingImage,
    required bool isPrivateProfile,
    
    // Metadata
    required bool isDirty,
    required bool isLoading,
    required ValidationError? error,
    
    // Original values for dirty detection
    required String originalUsername,
    required String originalAboutMe,
    required bool originalIsPrivate,
  }) = _ProfileFormState;
}
```

**StateNotifier Methods**:

### updateUsername(String value)
```dart
void updateUsername(String value) {
  state = state.copyWith(
    username: value.trim(),
    isDirty: _isDirty(
      username: value.trim(),
      aboutMe: state.aboutMe,
      isPrivate: state.isPrivateProfile,
    ),
    error: null, // Clear error when user modifies
  );
}
```
- Trims whitespace
- Detects changes vs original
- Clears previous validation error

### updateAboutMe(String value)
```dart
void updateAboutMe(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 500) {
    state = state.copyWith(
      aboutMe: trimmed,
      isDirty: _isDirty(...),
      error: null,
    );
  }
}
```
- Validates 500-char limit
- Trims whitespace
- Only updates if valid

### setImage(File imageFile)
```dart
Future<void> setImage(File imageFile) async {
  final validationError = await _validateImage(imageFile);
  if (validationError != null) {
    state = state.copyWith(error: validationError);
    return;
  }
  
  state = state.copyWith(
    pendingImage: imageFile,
    isDirty: true,
    error: null,
  );
}
```
- Client-side validation (format, size, dimensions)
- Returns specific validation error on failure
- Sets isDirty=true if valid

### removeImage()
```dart
void removeImage() {
  state = state.copyWith(
    pendingImage: null,
    isDirty: state.originalImage != null || _hasOtherChanges(),
    error: null,
  );
}
```
- Clears pendingImage
- isDirty remains if other fields changed, or was originally custom

### togglePrivacy(bool value)
```dart
void togglePrivacy(bool value) {
  state = state.copyWith(
    isPrivateProfile: value,
    isDirty: _isDirty(
      isPrivate: value,
      // ... other fields
    ),
  );
}
```
- Simple boolean toggle
- Detects change vs original

### validate()
```dart
ValidationError? validate() {
  // Validate all fields
  final usernameError = _validateUsername(state.username);
  if (usernameError != null) {
    state = state.copyWith(error: usernameError);
    return usernameError;
  }
  
  final bioError = _validateBio(state.aboutMe);
  if (bioError != null) {
    state = state.copyWith(error: bioError);
    return bioError;
  }
  
  return null; // All valid
}
```
- Server-side validation rules
- Sets error if any field invalid
- Returns error or null

### reset()
```dart
void reset() {
  state = state.copyWith(
    username: state.originalUsername,
    aboutMe: state.originalAboutMe,
    isPrivateProfile: state.originalIsPrivate,
    pendingImage: null,
    isDirty: false,
    error: null,
  );
}
```
- Reverts all fields to original values
- Clears error
- Sets isDirty=false

### save()
```dart
Future<void> save(Ref ref) async {
  final profileAsync = ref.watch(userProfileProvider(userId));
  final apiService = ref.watch(profileApiServiceProvider);
  
  state = state.copyWith(isLoading: true, error: null);
  
  try {
    // Step 1: Upload image if pending
    String? newImageUrl;
    if (state.pendingImage != null) {
      final response = await apiService.uploadImage(state.pendingImage!);
      newImageUrl = response.imageUrl;
    }
    
    // Step 2: Update profile fields
    final updatedProfile = await apiService.updateProfile(
      username: state.username,
      aboutMe: state.aboutMe,
      isPrivateProfile: state.isPrivateProfile,
    );
    
    // Step 3: Optimistic update to profile provider
    ref.read(userProfileProvider.notifier).setProfile(updatedProfile);
    
    // Step 4: Reset form state
    state = state.copyWith(
      isLoading: false,
      isDirty: false,
      pendingImage: null,
      originalUsername: updatedProfile.username,
      originalAboutMe: updatedProfile.aboutMe,
      originalIsPrivate: updatedProfile.isPrivateProfile,
      error: null,
    );
    
    // Step 5: Invalidate provider to reflect all changes
    ref.invalidate(userProfileProvider(userId));
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: _mapErrorToValidationError(e),
    );
  }
}
```
- Handles entire save flow: image upload → profile update → invalidation
- Optimistic update on success
- Specific error handling per failure type

---

## Validation Rule Functions

```dart
enum ValidationError {
  invalidUsername,
  invalidBio,
  imageFormatInvalid,
  imageTooLarge,
  imageDimensionsInvalid,
  networkError,
  serverError,
}

ValidationError? validateUsername(String username) {
  final trimmed = username.trim();
  
  if (trimmed.length < 3 || trimmed.length > 32) {
    return ValidationError.invalidUsername;
  }
  
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
    return ValidationError.invalidUsername;
  }
  
  return null;
}

ValidationError? validateBio(String bio) {
  if (bio.trim().length > 500) {
    return ValidationError.invalidBio;
  }
  return null;
}

Future<ValidationError?> validateImage(File imageFile) async {
  // Check format
  final ext = imageFile.path.split('.').last.toLowerCase();
  if (!['jpg', 'jpeg', 'png'].contains(ext)) {
    return ValidationError.imageFormatInvalid;
  }
  
  // Check size
  final size = await imageFile.length();
  if (size > 5 * 1024 * 1024) {
    return ValidationError.imageTooLarge;
  }
  
  // Check dimensions
  final bytes = await imageFile.readAsBytes();
  final image = decodeImage(bytes);
  if (image == null || image.width < 100 || image.height < 100 ||
      image.width > 5000 || image.height > 5000) {
    return ValidationError.imageDimensionsInvalid;
  }
  
  return null;
}
```

---

## Helper Functions

```dart
// Check if any field changed from original
bool _isDirty({
  required String username,
  required String aboutMe,
  required bool isPrivate,
  required File? pendingImage,
}) {
  return (username != state.originalUsername) ||
         (aboutMe != state.originalAboutMe) ||
         (isPrivate != state.originalIsPrivate) ||
         (pendingImage != null);
}

// Map error exceptions to user-facing ValidationError
ValidationError _mapErrorToValidationError(Object error) {
  if (error is SocketException) {
    return ValidationError.networkError;
  }
  if (error is HttpException) {
    if (error.statusCode == 400) {
      return ValidationError.invalidUsername; // or other field
    }
    if (error.statusCode == 413) {
      return ValidationError.imageTooLarge;
    }
  }
  return ValidationError.serverError;
}
```

---

## Usage Patterns in UI

### ProfileViewScreen
```dart
class ProfileViewScreen extends ConsumerWidget {
  final String userId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => ref.refresh(userProfileProvider(userId)),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => SkeletonLoader(),
        error: (error, stack) => ErrorWidget(
          error: error.toString(),
          onRetry: () => ref.refresh(userProfileProvider(userId)),
        ),
        data: (profile) => ProfileContent(profile: profile),
      ),
    );
  }
}
```

### ProfileEditScreen
```dart
class ProfileEditScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  
  @override
  void initState() {
    super.initState();
    final profile = ref
        .read(userProfileProvider)
        .whenData((p) => p); // Get current profile
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _bioController = TextEditingController(text: profile?.aboutMe ?? '');
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(profileFormStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!formState.isDirty) SizedBox.shrink(),
          if (formState.isDirty)
            TextButton(
              onPressed: formState.isLoading
                  ? null
                  : () => ref.read(profileFormStateProvider.notifier).save(ref),
              child: Text(formState.isLoading ? 'Saving...' : 'Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Form fields
            TextField(
              controller: _usernameController,
              onChanged: (value) => ref
                  .read(profileFormStateProvider.notifier)
                  .updateUsername(value),
            ),
            if (formState.error == ValidationError.invalidUsername)
              ErrorText('Username: 3-32 chars, letters/numbers/_/-'),
            // ... more fields
          ],
        ),
      ),
    );
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

## Testing Contracts

```dart
test('isDirty flag set on username change', () {
  final state = ProfileFormState.empty();
  final notifier = ProfileFormStateNotifier(initialProfile);
  
  notifier.updateUsername('new_name');
  
  expect(notifier.state.isDirty, true);
});

test('save() invalidates userProfileProvider', () async {
  final container = ProviderContainer();
  final notifier = container.read(profileFormStateProvider.notifier);
  
  await notifier.save(container);
  
  expect(
    container.read(userProfileProvider.select((p) => p.whenData((u) => u.isLoading))),
    AsyncValue.loading(),
  );
});

test('validation error set on invalid username', () {
  final notifier = ProfileFormStateNotifier(initialProfile);
  
  notifier.updateUsername('ab'); // Too short
  
  expect(notifier.state.error, ValidationError.invalidUsername);
});
```

---

*State Management Complete - Ready for implementation with Riverpod.*
