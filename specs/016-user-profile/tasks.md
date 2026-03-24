# Implementation Tasks: User Profile System

**Feature**: User Profile System  
**Branch**: `016-user-profile`  
**Generated**: March 13, 2026  
**Status**: Ready for Execution  
**Specification**: [spec.md](spec.md) | [Planning**: [plan.md](plan.md)

---

## Task Organization Strategy

Tasks organized in 7 phases: Setup → Foundational → Per User Story (P1 → P2) → Polish

**Format**: Each task follows strict checklist format
- `[TaskID]` - Sequential number (T001, T002, etc.)
- `[P]` - Parallelizable marker (different files, no blocking dependencies)
- `[USx]` - User story label (only in story phases)
- Description with exact file path

**Dependency Model**: Tasks within each phase can run in parallel; phases have sequential dependencies

---

## Phase 1: Setup & Project Initialization

### Phase 1 Goal
Establish feature branch, create directory structure, add dependencies, and prepare development environment.

### Test Criteria
- Git feature branch created and tracking upstream
- All directories created with proper structure
- pubspec.yaml updated with image_picker, riverpod
- Backend migrations ready (not applied yet)
- No compilation errors after pubspec updates

### Tasks

- [x] T001 Create feature branch `016-user-profile` from main with tracking
- [x] T002 Create frontend directory structure: `lib/features/profile/{models,screens,providers,services,widgets}`
- [x] T003 Create backend directory structure: `lib/src/{endpoints,services}` for profile feature
- [x] T004 Create test directories: `test/{unit,widget,integration}/features/profile/`
- [x] T005 [P] Add `image_picker: ^1.0.0` dependency to `frontend/pubspec.yaml`
- [x] T006 [P] Add `image: ^4.0.0` dependency to `frontend/pubspec.yaml` (for image validation)
- [x] T007 [P] Verify `riverpod: ^2.4.0` already in `frontend/pubspec.yaml`
- [x] T008 Run `flutter pub get` in frontend/ to resolve dependencies
- [x] T009 [P] Create database migration file `backend/migrations/014_create_profile_tables.dart` (scaffold only, not applied)
- [x] T010 Run Android build check: `flutter build apk --release --dry-run` to verify no immediate errors

---

## Phase 2: Foundational - Data Models & API Contracts

### Phase 2 Goal
Establish database layer, core models, and API contracts so all user stories can build on solid foundation.

### Test Criteria
- All models compile without errors
- API contract tests mock responses correctly
- Serialization/deserialization working
- No TypeErrors or null safety violations

### Tasks

- [x] T011 [P] Create `frontend/lib/features/profile/models/user_profile.dart` with UserProfile class (userId, username, profilePictureUrl, aboutMe, isPrivateProfile, updatedAt)
- [x] T012 [P] Create `frontend/lib/features/profile/models/profile_form_state.dart` with ProfileFormState (username, bio, pendingImage, isDirty, isLoading, error)
- [x] T013 [P] Create `frontend/lib/features/profile/models/validation_error.dart` enum (invalidUsername, invalidBio, imageFormatInvalid, imageTooLarge, imageDimensionsInvalid)
- [x] T014 [P] Create `backend/lib/src/models/profile_image.dart` with ProfileImage model (imageId, userId, imageUrl, fileSize, format, uploadedAt, deletedAt)
- [x] T015 Update `backend/lib/src/models/user.dart` to add profile fields (profilePictureUrl, aboutMe, isPrivateProfile, profileUpdatedAt)
- [x] T016 Create `frontend/lib/features/profile/services/profile_api_service.dart` with stub methods (fetchProfile, updateProfile, uploadImage, deleteImage)
- [x] T017 [P] Create `frontend/lib/core/constants/profile_constants.dart` with validation rules (MIN_USERNAME_LENGTH=3, MAX_USERNAME_LENGTH=32, MAX_BIO_LENGTH=500, MAX_IMAGE_SIZE=5242880, MIN_IMAGE_DIM=100, MAX_IMAGE_DIM=5000)
- [x] T018 Create `frontend/lib/features/profile/utils/validators.dart` with helper functions (validateUsername, validateBio, validateImage)
- [x] T019 Update `backend/lib/src/models/user.dart` with serialization logic for profile fields (toJson, fromJson)
- [x] T020 Verify all models pass `dart analyze` with no errors or warnings

---

## Phase 3: Backend - Profile API Endpoints

### Phase 3 Goal
Implement backend REST endpoints for profile operations: fetch, update, image upload, image delete.

### Test Criteria
- All endpoints callable via HTTP
- Response format matches API contract
- Error codes correct (400, 401, 403, 404, 413, 500)
- Image compression working
- File size and format validation working

### Tasks

- [x] T021 Run migration `backend/migrations/014_create_profile_tables.dart` to create User profile fields + ProfileImage table
- [x] T022 Create `backend/lib/src/services/profile_service.dart` with business logic methods
- [x] T023 [P] Implement ProfileService.getProfile(userId) - fetch user profile from database
- [x] T024 [P] Implement ProfileService.updateProfile(userId, username, bio, isPrivate) - validate and update
- [x] T025 [P] Implement ProfileService.uploadImage(userId, imageFile) - validate format/size/dims, compress to 500x500px, store securely
- [x] T026 [P] Implement ProfileService.deleteImage(userId) - soft-delete profile image record
- [x] T027 Create `backend/lib/src/endpoints/profile_endpoint.dart` with route handlers
- [x] T028 [P] Implement `GET /api/profile/:userId` endpoint - call ProfileService.getProfile, return JSON response
- [x] T029 [P] Implement `PUT /api/profile` endpoint - validate token, parse request body, call updateProfile, return 200
- [x] T030 [P] Implement `POST /api/profile/picture` endpoint - parse multipart form, call uploadImage, return 200 with imageUrl
- [x] T031 [P] Implement `DELETE /api/profile/picture` endpoint - validate token, call deleteImage, return 200
- [x] T032 Test all endpoints with curl/Postman - verify status codes, response format, error handling
- [x] T033 Add error handlers to endpoints (catch exceptions, return appropriate HTTP status + error message)
- [x] T034 Add rate limiting headers to profile endpoints (X-RateLimit-Limit, X-RateLimit-Remaining)
- [x] T035 Create `backend/migrations/015_add_profile_indexes.dart` for query optimization on profile_image and user tables

---

## Phase 4: User Story 1 (P1) - View My Profile

### Phase 4 Goal
Users can view their profile with picture, username, and bio displayed immediately. Implements read-only profile display.

### Independent Test Criteria
- User logs in → navigates to Profile tab → sees username, picture, bio within 500ms
- Profile displays username (non-editable)
- Profile displays about me (or placeholder if empty)
- Profile displays picture (default or custom)
- Profile displays privacy indicator (if private)
- Loading skeleton shows while fetching
- Error state shows with retry button
- Pull-to-refresh invalidates cache

### Implementation Tasks

- [x] T036 [P] Create `frontend/lib/features/profile/providers/user_profile_provider.dart` - FutureProvider that fetches profile from API
- [x] T037 [P] Create `frontend/lib/features/profile/widgets/profile_picture_widget.dart` - Displays circular profile image (120x120) with default avatar fallback
- [x] T038 Enhance `frontend/lib/features/profile/screens/profile_view_screen.dart` - Add profile picture display, username, bio, privacy indicator
- [x] T039 Add loading skeleton to ProfileViewScreen - show while fetching (3-second timeout simulation)
- [x] T040 Add error state to ProfileViewScreen - show error message + retry button
- [x] T041 Add empty bio placeholder to ProfileViewScreen - "No bio added yet" in gray/italics when bio is empty
- [x] T042 Add pull-to-refresh gesture to ProfileViewScreen - calls ref.refresh(userProfileProvider)
- [x] T043 Add privacy badge to ProfileViewScreen - lock icon + "Private Profile" text if isPrivateProfile = true
- [x] T044 [P] Implement ProfileApi.fetchProfile(userId) HTTP client method in profile_api_service.dart
- [x] T045 Test ProfileViewScreen on emulator - verify profile loads <500ms, displays correct data, icons render
- [x] T046 Test error state - simulate network error, verify retry button works
- [x] T047 Test empty/null fields - verify placeholders display correctly
- [x] T048 Add widget tests for ProfileViewScreen in `frontend/test/widget/features/profile/profile_view_screen_test.dart`

---

## Phase 5: User Story 2 (P1) - Edit My Profile Information

### Phase 5 Goal
Users can edit username and bio. Implements form state management, validation, and persistence.

### Independent Test Criteria  
- Edit screen shows pre-populated username + bio
- Form dirty flag works (Save button only enabled on changes)
- Username validation: 3-32 chars, alphanumeric+underscore+hyphen
- Bio validation: max 500 chars
- Save works: updates backend, shows success toast, pops screen
- Cancel works: reverts changes, pops screen
- Form maintains state on validation error
- Changes persist across app restart (backend save confirmed)

### Implementation Tasks

- [x] T049 [P] Create `frontend/lib/features/profile/providers/profile_form_state_provider.dart` - StateNotifierProvider for edit form
- [x] T050 [P] Create `frontend/lib/features/profile/providers/profile_form_state_notifier.dart` - StateNotifier with methods (updateUsername, updateBio, save, reset, validate)
- [x] T051 Implement updateUsername(String value) - trim, detect dirty flag, clear error
- [x] T052 Implement updateBio(String value) - trim to 500 chars max, detect dirty flag, clear error
- [x] T053 Implement reset() - revert to original values, set isDirty=false
- [x] T054 Implement validate() - check username/bio format, return ValidationError if invalid
- [x] T055 Implement save() - call API updateProfile(), invalidate cache on success, show toast
- [x] T056 Enhance `frontend/lib/features/profile/screens/profile_edit_screen.dart` - add TextEditingController initialization for username + bio
- [x] T057 [P] Add username text field with live character counter (3-32 limit) and validation error display
- [x] T058 [P] Add about me text area with live character counter (0-500 limit) and validation error display
- [x] T059 Add Save button - enabled only when isDirty=true, shows spinner during save
- [x] T060 Add Cancel button - always enabled, pops without saving (optional confirmation dialog)
- [x] T061 Add success toast notification - "Profile saved!" after successful API response
- [x] T062 Watch profileFormStateProvider in ProfileEditScreen - rebuild on state changes
- [x] T063 [P] Implement ProfileApi.updateProfile(username, bio, isPrivate) HTTP PUT method
- [ ] T064 Test form state transitions - update field → isDirty → enable save → cancel → revert
- [ ] T065 Test validation - invalid username → error shows → field stays populated → can fix + save
- [ ] T066 Test persistence - edit → save → logout/login → verify changes persist
- [x] T067 Add widget tests for ProfileEditScreen in `frontend/test/widget/features/profile/profile_edit_screen_test.dart`
- [x] T068 Add unit tests for form validation in `frontend/test/unit/features/profile/validators_test.dart`

---

## Phase 6: User Story 3 (P1) - Upload Profile Picture

### Phase 6 Goal
Users can select and upload JPEG/PNG images ≤5MB. Implements image picker integration, client-side validation, upload, and optimistic display.

### Independent Test Criteria
- Image picker opens (gallery + camera)
- JPEG upload succeeds, displays immediately
- PNG upload succeeds, displays immediately
- Image persists across app restart
- Other users see uploaded image on search
- Optimistic update: image shows before backend confirms

### Implementation Tasks

- [ ] T069 [P] Create `frontend/lib/features/profile/widgets/image_upload_widget.dart` - self-contained image picker + preview
- [ ] T070 Add image preview display to ImageUploadWidget (150x150 square, current image or default)
- [ ] T071 Add camera button to ImageUploadWidget - opens device camera via image_picker
- [ ] T072 Add gallery button to ImageUploadWidget - opens gallery via image_picker
- [ ] T073 Add remove button to ImageUploadWidget - visible only if custom image exists
- [ ] T074 Implement image picker initialization - request runtime permissions (gallery, camera)
- [ ] T075 Handle permission denials - show message "Please grant permission to upload photos"
- [x] T076 [P] Implement ProfileFormStateNotifier.setImage(File) - validate image, set state.pendingImage
- [x] T077 [P] Create image validation utility in `frontend/lib/features/profile/utils/image_validator.dart` - check format, size, dimensions
- [x] T078 Implement validateImage() async function - decode image, check JPEG/PNG, EXIF handling for iOS
- [ ] T079 Enhance ProfileEditScreen to include ImageUploadWidget
- [ ] T080 Add error display to ImageUploadWidget - show format/size/dimension errors inline
- [ ] T081 Add loading spinner during image upload - dim image, show spinner
- [ ] T082 [P] Implement ProfileApi.uploadImage(File imageFile) - HTTP POST multipart/form-data
- [ ] T083 On successful upload response (200) - extract imageUrl, optimistically update profile
- [ ] T084 Update userProfileProvider with optimistic data - setProfile() called on successful upload
- [ ] T085 Invalidate cache after upload - ensure fresh profile data
- [ ] T086 Test image selection - gallery and camera work, file returned
- [ ] T087 Test image validation - JPEG/PNG valid, GIF/BMP rejected with error message
- [ ] T088 Test size validation - 5MB accepted, 5MB+1byte rejected with "File must be smaller than 5MB"
- [ ] T089 Test dimensions - 100x100px accepted, 99x99px rejected; 5000x5000px accepted, 5001x5001px rejected
- [ ] T090 Test optimistic update - image shows immediately on success response (before data fetch)
- [ ] T091 Test persistence - upload image → logout/login → image still there
- [ ] T092 Add widget tests for ImageUploadWidget in `frontend/test/widget/features/profile/image_upload_widget_test.dart`
- [ ] T093 Add image validation unit tests in `frontend/test/unit/features/profile/image_validator_test.dart`

---

## Phase 7: User Story 4 (P2) - Validate Image Format & Size

### Phase 7 Goal
System provides specific error messages for invalid images, guiding users to correct issues.

### Independent Test Criteria
- GIF upload rejected: "Only JPEG and PNG formats are supported"
- BMP upload rejected: "Only JPEG and PNG formats are supported"
- 6MB image rejected: "File must be smaller than 5MB"
- Form maintains state after error
- User can retry with valid file immediately

### Implementation Tasks

- [ ] T094 [P] Enhance validateImage() to return specific ValidationError enum value
- [ ] T095 [P] Add format validation - check file extension and decoded image type are JPEG/PNG
- [ ] T096 [P] Add size validation - file.lengthSync() ≤ 5,242,880 bytes
- [ ] T097 Map ValidationError enum to user-friendly error strings in `frontend/lib/features/profile/utils/error_messages.dart`
- [ ] T098 Display errors inline in ImageUploadWidget - red border + error text below
- [ ] T099 Test error messages - each validation error shows correct message (no generic "Error")
- [ ] T100 Test form state after error - fields maintain values, user can select new file
- [ ] T101 Backend validation - implement same checks server-side, return 400/413 with appropriate error
- [ ] T102 Test backend errors - POST with invalid image, verify correct HTTP status + error response
- [ ] T103 Add integration test for validation error flow in `frontend/test/integration/profile_flow_test.dart`

---

## Phase 8: User Story 5 (P2) - Remove Picture & Revert to Default

### Phase 8 Goal
Users can delete custom picture and revert to default avatar.

### Independent Test Criteria
- Remove button visible only if custom image exists
- Tap Remove → picture deleted from backend
- Default avatar displays after removal
- Removal persists across app restart
- API DELETE endpoint responds correctly

### Implementation Tasks

- [ ] T104 Add Remove button to ImageUploadWidget - visible only if state.currentImage != null
- [ ] T105 [P] Implement ProfileFormStateNotifier.removeImage() - clear pendingImage, set isDirty=true if was custom
- [ ] T106 [P] Implement ProfileApi.deleteImage() HTTP DELETE `/api/profile/picture` endpoint
- [ ] T107 On DELETE success - clear profile picture, show default avatar
- [ ] T108 Invalidate userProfileProvider after delete - force fresh profile fetch
- [ ] T109 Test remove button visibility - shows only when custom image exists
- [ ] T110 Test removal flow - tap remove → confirm (optional) → backend called → avatar changes
- [ ] T111 Test persistence - remove picture → logout/login → default avatar still there
- [ ] T112 Backend test - DELETE endpoint with valid token returns 200, without token returns 401
- [ ] T113 Backend test - DELETE when no custom image returns 404 with appropriate message

---

## Phase 9: User Story 6 (P2) - Privacy Controls

### Phase 9 Goal
Users can toggle profile between public (visible to all) and private (visible to contacts only in future).

### Independent Test Criteria
- Privacy toggle visible in edit mode
- Toggle persists across sessions
- Private profile shows lock icon on view screen
- Public profile has no lock icon
- Default: public (false)

### Implementation Tasks

- [ ] T114 [P] Add privacy toggle to ProfileEditScreen - SwitchListTile with "Private Profile" label
- [ ] T115 [P] Implement profileFormStateNotifier.togglePrivacy(bool) - set state.isPrivateProfile
- [ ] T116 Include isPrivateProfile in PUT /api/profile request body
- [ ] T117 Update backend to save isPrivateProfile field in User table
- [ ] T118 Add privacy badge to ProfileViewScreen - lock icon + "Private Profile" if isPrivateProfile=true
- [ ] T119 Add description text to toggle - "Only contacts can see your profile" (future feature)
- [ ] T120 Test privacy toggle - on → off → persists
- [ ] T121 Test privacy display - private profile shows lock icon, public profile doesn't
- [ ] T122 Test default - new profile has isPrivateProfile=false

---

## Phase 10: User Story 7 (P2) - Search & View Other User Profiles

### Phase 10 Goal
Users can search for and view other users' profiles in read-only mode.

### Independent Test Criteria
- Search results show other users
- Tap result → view their profile
- Other user's profile shows picture, username, bio (if public)
- No Edit button on other user's profile
- Private profile shows lock icon

### Implementation Tasks

- [ ] T123 [P] Enhance search result handling - add navigation to ProfileViewScreen(userId: selectedUserId)
- [ ] T124 [P] Enhance ProfileViewScreen - detect if viewing own profile vs other user
- [ ] T125 Show Edit button only if isOwnProfile=true
- [ ] T126 Show Message/Add Friend buttons only if isOwnProfile=false (UI placeholders for future)
- [ ] T127 If viewing private profile and no permission (future) - show "Private Profile" message
- [ ] T128 Test viewing own profile - shows Edit button
- [ ] T129 Test viewing other profile - no Edit button, shows Message button
- [ ] T130 Test private other profile - shows lock icon + limited info

---

## Phase 11: Polish & Edge Cases

### Phase 11 Goal
Handle edge cases, improve performance, add accessibility, ensure robust error handling.

### Test Criteria
- Profile loads <500ms average
- Images display <2 seconds
- No memory leaks with image loading
- App handles network errors gracefully
- Permission denials handled
- Accessibility: labels, focus order, color contrast

### Tasks

- [ ] T131 [P] Add offline support - cache profile locally using flutter_secure_storage
- [ ] T132 [P] Implement profile data fallback from local cache if network unavailable
- [ ] T133 Add permission handling - request gallery/camera permissions, show error if denied
- [ ] T134 Add network timeout handling - 30 second timeout on API calls, show retry
- [ ] T135 Add rapid-fire upload protection - ignore duplicate uploads within 1 second
- [ ] T136 Handle concurrent edits - last write wins (acceptable for MVP)
- [ ] T137 Add image orientation handling - server-side compression handles EXIF
- [ ] T138 [P] Add accessibility labels to all buttons (camera, gallery, remove, edit, save, cancel)
- [ ] T139 [P] Ensure touch targets minimum 48x48 dp
- [ ] T140 [P] Verify text has sufficient color contrast (WCAG AA 4.5:1)
- [ ] T141 Add loading animation - progress indicator during image upload
- [ ] T142 Add image upload progress - show percentage complete during large file uploads
- [ ] T143 Optimize image loading - use CachedNetworkImage with memory + disk cache
- [ ] T144 Profile performance profiling - measure load time, identify bottlenecks
- [ ] T145 Test on slow network (3G throttling in DevTools) - verify UI remains responsive
- [ ] T146 [P] Add null safety checks to all nullable fields
- [ ] T147 Add logging for debugging - log API requests/responses (non-sensitive data only)
- [ ] T148 Test edge case: user with no custom picture - default avatar displays
- [ ] T149 Test edge case: user with empty bio - placeholder shows
- [ ] T150 Test edge case: form changes during network delay - state maintained
- [ ] T151 Test edge case: app backgrounded during upload - resume gracefully
- [ ] T152 Test edge case: invalid response from backend - show error, allow retry

---

## Phase 12: Testing - Unit, Widget, Integration

### Phase 12 Goal
Comprehensive test coverage: unit tests for validators, widget tests for UI, integration test for full flow.

### Test Criteria
- Unit tests: 100% coverage for validators
- Widget tests: All components render correctly
- Integration test: Full edit/upload/view flow works end-to-end
- All tests passing, no flakiness

### Tasks

- [ ] T153 Create unit test file `frontend/test/unit/features/profile/validators_test.dart`
- [ ] T154 [P] Write tests for validateUsername - valid/invalid cases, edge cases (min 3, max 32)
- [ ] T155 [P] Write tests for validateBio - max 500 chars, empty allowed
- [ ] T156 [P] Write tests for validateImage async - format (JPEG/PNG), size (≤5MB), dimensions (100-5000px)
- [ ] T157 Create widget test file `frontend/test/widget/features/profile/profile_view_screen_test.dart`
- [ ] T158 [P] Write test - profile displays when loaded
- [ ] T159 [P] Write test - error state with retry button
- [ ] T160 [P] Write test - empty bio placeholder
- [ ] T161 Create widget test file `frontend/test/widget/features/profile/profile_edit_screen_test.dart`
- [ ] T162 [P] Write test - form fields pre-populated
- [ ] T163 [P] Write test - Save button disabled until dirty
- [ ] T164 [P] Write test - validation errors display inline
- [ ] T165 Create widget test file `frontend/test/widget/features/profile/image_upload_widget_test.dart`
- [ ] T166 [P] Write test - image preview displays
- [ ] T167 [P] Write test - camera/gallery buttons responsive
- [ ] T168 [P] Write test - error message shows for invalid image
- [ ] T169 Create integration test file `frontend/test/integration/profile_flow_test.dart`
- [ ] T170 Write full flow test - edit form → upload image → save → verify changes
- [ ] T171 Write error recovery test - invalid image → error → retry with valid → success
- [ ] T172 Write offline test - load profile from cache if network unavailable
- [ ] T173 Run all tests locally - `flutter test` with 100% pass rate
- [ ] T174 Run tests on CI/CD pipeline - verify in build gates
- [ ] T175 [P] Add Android instrumentation tests via github actions/emulator

---

## Phase 13: Documentation & Code Quality

### Phase 13 Goal
Document code, ensure clean architecture, prepare for code review and maintenance.

### Tasks

- [ ] T176 Add dartdoc comments to all public methods in profile models
- [ ] T177 Add dartdoc comments to ProfileApiService methods
- [ ] T178 Add dartdoc comments to validators
- [ ] T179 Create API contract documentation in `frontend/lib/features/profile/README.md`
- [ ] T180 [P] Run `dart analyze` - 0 errors, 0 warnings
- [ ] T181 [P] Run `flutter format` - consistent code formatting
- [ ] T182 [P] Run `dart fix` - apply recommended fixes
- [ ] T183 Verify naming conventions - snake_case files, PascalCase classes, camelCase methods (Constitution Check)
- [ ] T184 Review Constitution compliance - Security-First, Architecture clarity, Testing Discipline
- [ ] T185 Create IMPLEMENTATION_NOTES.md with architecture decisions and code patterns
- [ ] T186 Generate Android APK - `flutter build apk --release`
- [ ] T187 Test Android APK on emulator - profile features work end-to-end
- [ ] T188 Test iOS build - `flutter build ios` (if applicable)

---

## Phase 14: Code Review & Merge

### Phase 14 Goal
Prepare for code review, address feedback, merge to main.

### Tasks

- [ ] T189 Commit all changes with descriptive messages: `git commit -m "feat(profile): implement [feature]"`
- [ ] T190 Push feature branch: `git push origin 016-user-profile`
- [ ] T191 Create pull request against main with changelog
- [ ] T192 Verify CI/CD pipeline - all checks passing (tests, linting, build)
- [ ] T193 Address code review feedback - iterate on reviewer comments
- [ ] T194 Verify one final time - Android APK builds, all tests pass, no console errors
- [ ] T195 Squash commits if needed - clean git history
- [ ] T196 Request final approvals - ensure Constitution Check verified by reviewer
- [ ] T197 Merge to main - delete feature branch after merge
- [ ] T198 Tag release - create git tag for version (if applicable)
- [ ] T199 Update main README.md with feature documentation
- [ ] T200 Celebrate! 🎉 Feature complete and deployed

---

## Task Statistics

### By Phase
| Phase | Count | Category |
|-------|-------|----------|
| 1 (Setup) | 10 | Setup & dependencies |
| 2 (Foundational) | 10 | Models & contracts |
| 3 (Backend APIs) | 15 | Endpoints & business logic |
| 4 (US1) | 13 | View profile |
| 5 (US2) | 20 | Edit profile |
| 6 (US3) | 25 | Upload image |
| 7 (US4) | 10 | Image validation |
| 8 (US5) | 10 | Remove picture |
| 9 (US6) | 9 | Privacy controls |
| 10 (US7) | 8 | Search & view other profiles |
| 11 (Polish) | 22 | Edge cases & performance |
| 12 (Testing) | 23 | Unit/widget/integration tests |
| 13 (Documentation) | 11 | Code quality & docs |
| 14 (Review) | 11 | Code review & merge |
| **TOTAL** | **200** | **Complete feature** |

### By Parallelizability
- **Parallelizable [P]**: 89 tasks (can run simultaneously on different files)
- **Sequential**: 111 tasks (have dependencies)
- **Parallel Efficiency**: 44% of tasks can run in parallel (89/200)

### By User Story
| Story | Priority | Tasks | Status |
|-------|----------|-------|--------|
| US1: View Profile | P1 | 13 | Phase 4 |
| US2: Edit Profile | P1 | 20 | Phase 5 |
| US3: Upload Image | P1 | 25 | Phase 6 |
| US4: Validate Image | P2 | 10 | Phase 7 |
| US5: Remove Picture | P2 | 10 | Phase 8 |
| US6: Privacy | P2 | 9 | Phase 9 |
| US7: Search Other | P2 | 8 | Phase 10 |

---

## Dependencies & Critical Path

```
Phase 1: Setup (independent)
  ↓
Phase 2: Foundational (unblocks backend & frontend)
  ├→ Phase 3: Backend APIs (5-7 days)
  │   └→ Phase 4-10: User Stories (7-10 days, can start once APIs stubbed)
  └→ Phase 4-10: User Stories (parallel with backend, mock APIs)
  
Phase 11: Polish (after Phase 10)
  ↓
Phase 12: Testing (on-going during all phases, formal in Phase 12)
  ↓
Phase 13: Documentation (parallel with all phases)
  ↓
Phase 14: Code Review & Merge (final)
```

### Critical Path
1. Phase 1 (Setup) - 1 day
2. Phase 2 (Foundational) - 1 day
3. Phase 3 (Backend) **or** Phase 4-10 (Frontend) - 7 days in parallel
4. Phase 4-10 (if doing Backend first) - 7-10 days
5. Phase 11 (Polish) - 1-2 days
6. Phase 12 (Testing) - 2 days (mostly parallel)
7. Phase 13-14 (Review) - 1-2 days

**Total Timeline**: 10-14 days (with parallelization)

---

## MVP Scope (First Week)

**Define MVP as: Phases 1-6 + partial Phase 12**

### MVP Tasks (Days 1-7)
- T001-T010: Setup
- T011-T020: Data models
- T021-T035: Backend endpoints (basic implementation, no rate limiting)
- T036-T048: View profile user story
- T049-T068: Edit profile user story
- T069-T093: Upload image user story
- T173: Run basic tests

**MVP Result**: Users can view/edit profile and upload images. Validation, privacy, and advanced features in Phase 2.

---

## Parallel Execution Examples

### Day 1 Parallel Work
**Backend Team**: T021-T026 (implement ProfileService methods)  
**Frontend Team**: T011-T020 (create models and validators)

### Days 3-4 Parallel Work (after Phase 2)
**Backend**: T027-T035 (implement endpoints)  
**Frontend**: T036-T048 (ProfileViewScreen implementation)  
**Quality**: T153-T160 (unit and widget test setup)

### Days 5-6 Parallel Work
**Backend**: T021-T026 complete, testing  
**Frontend US1**: T036-T048 complete  
**Frontend US2**: T049-T068 in progress  
**Frontend US3**: T069-T093 in progress (can start after image_picker added)

---

## Completion Metrics

**Task Progress Tracking**:
- Mark complete as implemented and tested
- Mark blocked if dependency not ready
- Track estimated vs actual time per phase

**Quality Gates**:
- Phase must have 100% test pass rate before proceeding
- All Constitution principle checks must pass
- Code review approval required before merge

**Delivery Checklist**:
- [ ] All 200 tasks completed
- [ ] 0 failing tests
- [ ] Android APK builds and runs
- [ ] No console errors or warnings
- [ ] Code review approved
- [ ] Merged to main

---

## Implementation Notes

### Tech Stack Recap
- **Frontend**: Flutter 3.12.0+, Riverpod 2.4.0, image_picker 1.0.0
- **Backend**: Dart/Serverpod, PostgreSQL
- **Testing**: flutter_test, mockito, golden tests
- **Architecture**: MVVM (screens) + state management (Riverpod) + service layer

### Key Decisions Documented
- See [research.md](research.md) for technical decisions
- See [data-model.md](data-model.md) for data contracts
- See [quickstart.md](quickstart.md) for implementation guide
- See [contracts/](contracts/) for API and UI specifications

### Continuation
After task completion:
1. Tag release version (e.g., v0.2.0)
2. Create follow-up issues for P3 features (advanced privacy, profile badges, etc.)
3. Plan performance optimization phase if needed
4. Monitor production metrics (load time, error rates)

---

*Tasks Complete - Ready for Implementation - Total 200 tasks across 14 phases*
