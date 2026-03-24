# Tasks: User Profile System (Spec 005)

**Spec Reference**: `/specs/005-profile-system/`  
**Timeline**: Days 1-8 (8 days total)  
**MVP Scope**: View profile → Edit profile → Upload image (all 6 scenarios from spec.md)  
**Team Size**: 2 developers (1 backend, 1 frontend) | Parallel execution recommended

---

## Overview

Implement user profile viewing, editing, and profile picture upload functionality. Users can customize their profile with picture, username, bio, and privacy settings. The system supports image upload (JPEG/PNG, ≤5MB), persistence across sessions, and privacy controls. Implementation spans 4 phases: database schema updates (Phase 1), backend services and endpoints (Phase 2), frontend UI screens (Phase 3), and integration testing (Phase 4).

---

## Phase 1: Setup & Database Layer

**Duration**: Day 1 (~4 hours)  
**Responsible**: Backend Developer  
**Dependencies**: None (builds on existing Spec 002-003 infrastructure)  
**Parallel**: Not applicable (sequential database setup)

### Tasks

- [ ] T001 Create migration 011_add_profile_fields_to_user.dart in backend/migrations/
- [ ] T002 Create migration 012_create_profile_image_table.dart in backend/migrations/
- [ ] T003 Register migrations in backend/lib/src/services/database_service.dart
- [ ] T004 Run migrations via docker-compose restart and verify in logs
  - Acceptance criteria: Verify no errors in migration output
  - Verify `user` table has new columns: profile_picture_url, about_me, is_default_profile_picture, is_private_profile, profile_updated_at
  - Verify `profile_image` table created with all columns
  - Verify database constraints: CHECK on file_size_bytes, UNIQUE on (user_id, is_active), NOT NULL on required fields
  - Test constraint enforcement: attempt to insert file >5MB, verify error thrown; attempt duplicate is_active, verify error thrown

---

## Phase 2: Backend Service Implementation

**Duration**: Days 2-3 (~12 hours)  
**Responsible**: Backend Developer  
**Dependencies**: T001, T002, T003, T004 (Phase 1 complete)  
**Parallel Opportunities**: T006-T010 can run in parallel during service development; T011-T015 endpoints can be built concurrently after service is ready

### Part A: Core Service

- [ ] T005 [P] Implement ProfileService in backend/lib/src/services/profile_service.dart with methods: getProfile(userId, requester), updateProfile(userId, data), uploadProfilePicture(userId, file), removeProfilePicture(userId)

### Part B: Models & Serialization

- [ ] T006 [P] Create UserProfile model in backend/lib/src/models/user_profile.dart with toJson() and fromJson() methods
- [ ] T007 [P] Create ProfileImage model in backend/lib/src/models/profile_image.dart with database serialization

### Part C: Validation & Image Processing

- [ ] T008 [P] Implement image validation in backend/lib/src/services/profile_service.dart: format check (JPEG/PNG only), size check (≤5MB), dimension check (100x100 to 5000x5000)
- [ ] T009 [P] Implement image processing in backend/lib/src/services/profile_service.dart: center crop, resize to 500x500, compress to 85% JPEG quality using image package v4.0+
  - Verify image package v4.0+ strips EXIF metadata during compression (test that no metadata present in output)
- [ ] T010 [P] Create static file middleware in backend/lib/src/middleware/static_files.dart for serving profile pictures from /uploads/profiles/ directory

### Part D: API Endpoints

- [ ] T011 [P] Implement GET /profile/view/{userId} endpoint in backend/lib/src/endpoints/profile_handler.dart (public access, privacy check)
- [ ] T012 [P] Implement PATCH /profile/edit endpoint in backend/lib/src/endpoints/profile_handler.dart (authenticated, updates username/aboutMe/isPrivateProfile)
- [ ] T013 [P] Implement POST /profile/picture/upload endpoint in backend/lib/src/endpoints/profile_handler.dart (multipart form, image processing, respond with URL)
- [ ] T014 [P] Implement DELETE /profile/picture endpoint in backend/lib/src/endpoints/profile_handler.dart (delete custom image, revert to default)

### Part E: Error Handling & Integration

- [ ] T015 Register ProfileService and profile endpoints with Shelf router in backend/lib/src/server.dart

---

## Phase 3: Frontend Implementation

**Duration**: Days 4-5 (~12 hours)  
**Responsible**: Frontend Developer  
**Dependencies**: T011-T014 (backend endpoints ready)  
**Parallel Opportunities**: T016-T020 can be built in parallel; T022-T024 can start after T021

### Part A: State Management

- [ ] T016 [P] Create userProfileProvider Riverpod FutureProvider in frontend/lib/features/profile/providers/user_profile_provider.dart (GET /profile/view, 5-minute cache TTL)
- [ ] T017 [P] Create profileEditFormNotifier Riverpod StateNotifier in frontend/lib/features/profile/providers/profile_edit_provider.dart (manage username, aboutMe, isPrivateProfile form state)
- [ ] T018 [P] Create profileImageNotifier Riverpod StateNotifier in frontend/lib/features/profile/providers/profile_image_provider.dart (track selected image, upload progress, errors)

### Part B: Backend Service & Image Picker

- [ ] T019 [P] Create ProfileService (HTTP wrapper) in frontend/lib/features/profile/services/profile_service.dart with methods: getProfile(userId), updateProfile(data), uploadImage(file), deleteImage()
- [ ] T020 [P] Create ImagePickerService wrapper in frontend/lib/features/profile/services/image_picker_service.dart (select image, validate locally before upload)

### Part C: UI Screens

- [ ] T021 [US1] Create ProfileViewScreen in frontend/lib/features/profile/screens/profile_view_screen.dart (display picture, username, aboutMe, privacy status; Edit/Privacy buttons for own profile)
- [ ] T022 [US2] Create ProfileEditScreen in frontend/lib/features/profile/screens/profile_edit_screen.dart (editable username/aboutMe fields, Save/Cancel buttons, image picker integration)
- [ ] T023 [US3] [P] Create ProfileImageUploadWidget in frontend/lib/features/profile/widgets/profile_image_upload_widget.dart (image picker button, preview, Remove Picture button, upload progress indicator)
- [ ] T024 [US3] [P] Implement image picker integration in ProfileImageUploadWidget: accept JPEG/PNG, client-side format/size validation, show error snackbars

### Part D: Navigation & Integration

- [ ] T025 Wire ProfileViewScreen and ProfileEditScreen into app navigation (via go_router in frontend/lib/app.dart)

---

## Phase 4: Integration & Testing

**Duration**: Days 6-8 (~8 hours)  
**Responsible**: Both Developers (collaborative testing)  
**Dependencies**: T001-T024 (all implementation phases complete)  
**Test Execution**: Sequential (each scenario builds on previous state)

### Part A: Unit Tests (Image Processing)

- [ ] T026-unit Create unit tests in backend/test/unit/image_processing_test.dart for image validation and processing logic:
  - Test ImageValidator: format detection (JPEG, PNG, GIF rejection), size bounds (100x100 min, 5000x5000 max), file size limits (5MB)
  - Test ImageProcessor: crop to square, resize to 500x500px, JPEG compression at 85% quality, verify output dimensions and quality
  - Test EXIF stripping: verify metadata absent in processed output

### Part B: Backend Integration Tests

- [ ] T026 [P] Create integration test suite in backend/test/integration/profile_integration_test.dart: GET /profile/view happy path (public profile, private profile, default image, custom image)
- [ ] T027 [P] Create integration test: PATCH /profile/edit with valid data (username update, aboutMe update, privacy toggle)
- [ ] T028 [P] Create integration test: POST /profile/picture/upload with valid JPEG/PNG ≤5MB, verify server response and file storage
- [ ] T029 [P] Create integration test: POST /profile/picture/upload with invalid format (GIF, BMP, WEBP), expect HTTP 400 with "jpeg or png" message
- [ ] T030 [P] Create integration test: POST /profile/picture/upload with file >5MB, expect HTTP 413 with "5MB" message
- [ ] T031 [P] Create integration test: DELETE /profile/picture, verify default image returns, custom image deleted from filesystem

### Part B: Frontend Widget Tests

- [ ] T032 [P] Create widget test for ProfileViewScreen in frontend/test/features/profile/screens/profile_view_screen_test.dart (display profile data, conditional Edit button)
- [ ] T032a Create widget test for Riverpod cache behavior in frontend/test/features/profile/providers/user_profile_provider_test.dart:
  - Load profile → verify cache active for 5 minutes
  - Wait 5+ minutes → verify provider re-fetches data or requires manual refresh
  - Verify cache invalidated on edit (profile changes trigger fresh fetch)
  - If manual refresh button present: verify it triggers new fetch immediately
- [ ] T033 [P] Create widget test for ProfileEditScreen in frontend/test/features/profile/screens/profile_edit_screen_test.dart (edit fields, Save button enabled only on change, Cancel discards)
- [ ] T034 [P] Create widget test for ProfileImageUploadWidget in frontend/test/features/profile/widgets/profile_image_upload_widget_test.dart (image picker flow, validation errors)

### Part C: E2E & Manual Testing

- [ ] T035 Execute E2E test scenario 1 (First login - default profile): New user logs in → ProfileViewScreen displays default image + username + empty bio
- [ ] T036 Execute E2E test scenario 2 (Edit profile): Edit username to "NewUser123" + aboutMe to "Hello" → Save → Logout/Login → Data persists
- [ ] T037 Execute E2E test scenario 3-6 (Image upload): Upload valid JPEG ✓, PNG ✓, 5MB ✓, reject GIF ✓, reject 6MB ✓, remove picture reverts to default ✓
- [ ] T038 Manual testing checklist: (1) Privacy toggle enables/disables profile visibility, (2) Image upload <2s, (3) Error messages are specific (format/size), (4) Profile cache refreshes after edit, (5) Cross-user profile view works, (6) Concurrent uploads don't corrupt state
- [ ] T038a Performance validation testing:
  - Measure profile view latency (GET /profile/view): Assert <300ms
  - Measure profile edit latency (PATCH /profile/edit): Assert <500ms
  - Measure image upload latency (POST /profile/picture/upload with 5MB file): Assert <2s
  - Use curl with time measurement: `time curl -X GET http://localhost:8081/profile/view/{userId}`
  - Document results with timestamp; if any SLA exceeded, investigate caching strategy or database query optimization

---

## Dependencies & Execution Strategy

### Task Dependency Graph

```
Phase 1 (Sequential):
T001 → T002 → T003 → T004

Phase 2 (Mostly Parallel):
T004 → T005 (then parallel: T006, T007, T008, T009, T010)
       ↓
    T006, T007, T008, T009, T010 → T011, T012, T013, T014 (parallel)
       ↓
    T011-T014 → T015

Phase 3 (Mostly Parallel):
T015 → T016, T017, T018, T019, T020 (parallel) → T021
                                                  ↓
                                        T022, T023, T024 (parallel after T021)
                                                  ↓
                                              T025

Phase 4 (Mostly Parallel):
T025 → T026-T034 (parallel) → T035-T038 (sequential E2E)
```

### Parallel Execution Opportunities

**Backend Phase 2** (~12 hours → ~4-6 hours parallelized):
- Developer A: T005 (ProfileService core logic)
- Developer B: T006, T007 (models) in parallel with Developer A
- Both: T008, T009, T010 (validation/processing/middleware) in parallel
- Both: T011-T014 (endpoints) in parallel after service ready
- Together: T015 (integration)

**Frontend Phase 3** (~12 hours → ~6-8 hours parallelized):
- Developer A: T016, T017, T018 (providers) in parallel
- Developer B: T019, T020 (services) in parallel with Developer A
- Developer A: T021 (ProfileViewScreen after providers ready)
- Developer B: T022 (ProfileEditScreen) in parallel with Developer A
- Both: T023, T024 (image upload widget) in parallel
- Together: T025 (navigation integration)

**Testing Phase 4** (~8 hours → ~4-6 hours parallelized):
- Developer A: T026-T031 (backend integration tests, can run in parallel)
- Developer B: T032-T034 (frontend widget tests, can run in parallel)
- Together: T035-T038 (E2E scenarios, must run sequentially but fast)

**Estimated Total Time**:
- Sequential execution: 32-36 hours
- Parallel execution (2 devs): 16-18 hours
- Critical path: Phase 1 (4h) → Phase 2 (6h parallelized) → Phase 3 (6h parallelized) → Phase 4 (3-4h parallelized) ≈ 19-20 hours wall-time

---

## Task Checklist Format Reference

Each task follows this format:
```
- [ ] [TaskID] [P?] [Story?] Description with exact file path
```

**Components**:
- **[TaskID]**: T001-T038 (sequential within phase)
- **[P]**: Marks parallelizable tasks (can run alongside others in same phase)
- **[Story]**: Tags for specific user story (not used in this spec, included for consistency)
- **Description**: Clear action with file path

---

## Implementation Notes

### Phase 1: Database Setup

**Migrations Location**: `backend/migrations/`  
**Pattern**: Follow existing migrations (001-010) in the project  
**Verification Command**: 
```bash
docker-compose exec backend psql -U messenger_user -d messenger_db -c "\dt"
# Verify: user table has profile_picture_url, about_me, is_default_profile_picture, is_private_profile, profile_updated_at columns
# Verify: profile_image table exists with all required columns
```

**Index Verification**:
```bash
docker-compose exec backend psql -U messenger_user -d messenger_db -c "\d+ user" | grep idx_user_is_private
docker-compose exec backend psql -U messenger_user -d messenger_db -c "\d+ user" | grep idx_user_profile_updated_at
docker-compose exec backend psql -U messenger_user -d messenger_db -c "\d+ profile_image" | grep idx_profile_image
```

---

### Phase 2: Backend Implementation

**Service Location**: `backend/lib/src/services/profile_service.dart`  
**Endpoints Location**: `backend/lib/src/endpoints/profile_handler.dart`  
**Models Location**: `backend/lib/src/models/`

**Key Implementation Details**:
- All endpoints require auth middleware check (except GET /profile/view for public profiles)
- Privacy check: If `is_private_profile = true`, only owner can view (return 403 Forbidden otherwise)
- Image processing: Use `image` package v4.0+ for JPEG compression, crop to square, resize 500x500
- File storage: Save to `/uploads/profiles/` with naming pattern `{userId}-{timestamp}.jpg`
- Error messages:
  - Format error: `"Only JPEG and PNG formats are supported"` (HTTP 400)
  - Size error: `"File must be smaller than 5MB"` (HTTP 413)
  - Dimension error: `"Image must be between 100x100 and 5000x5000 pixels"` (HTTP 400)
  - Permission error: `"Forbidden"` (HTTP 403, no details)
  - Server error: `"Unable to process request"` (HTTP 500, generic)

**Code Templates**: See `/specs/005-profile-system/quickstart.md` for complete implementation examples

---

### Phase 3: Frontend Implementation

**Providers Location**: `frontend/lib/features/profile/providers/`  
**Services Location**: `frontend/lib/features/profile/services/`  
**Screens Location**: `frontend/lib/features/profile/screens/`  
**Widgets Location**: `frontend/lib/features/profile/widgets/`

**Riverpod Setup**:
```dart
// userProfileProvider: FutureProvider<UserProfile>
// Cache TTL: 5 minutes (invalidate on edit)
// Parameters: userId (required)

// profileEditFormNotifier: StateNotifier<ProfileEditFormState>
// Tracks: username, aboutMe, isPrivateProfile, isDirty (for Save button)

// profileImageNotifier: StateNotifier<ProfileImageState>
// Tracks: selectedFile, uploadProgress, error, isUploading
```

**Image Picker Integration**:
- Use `image_picker` package (flutter_pub)
- Client-side validation: format (.jpg, .jpeg, .png only), size < 5MB
- Show error snackbar if validation fails
- Progress indicator during upload

**Navigation Pattern**:
```dart
// ProfileViewScreen: /profile/{userId}
// ProfileEditScreen: /profile/{userId}/edit
// Route back after successful edit
```

---

### Phase 4: Integration & Testing

**Backend Test Location**: `backend/test/integration/profile_integration_test.dart`  
**Frontend Test Location**: `frontend/test/features/profile/`

**Test Execution**:
```bash
# Backend integration tests
cd backend && dart test test/integration/profile_integration_test.dart

# Frontend widget tests
cd frontend && flutter test test/features/profile/

# E2E testing: Use cURL for backend, manual Flutter app for frontend
```

**cURL Examples**:
```bash
# Get public profile (no auth required)
curl -X GET http://localhost:8081/profile/view/{userId}

# Get own profile (auth required, private allowed)
curl -X GET http://localhost:8081/profile/view/{userId} \
  -H "Authorization: Bearer {token}"

# Edit profile (auth required)
curl -X PATCH http://localhost:8081/profile/edit \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"username": "NewName", "aboutMe": "Hello", "isPrivateProfile": false}'

# Upload profile picture (auth required, multipart form)
curl -X POST http://localhost:8081/profile/picture/upload \
  -H "Authorization: Bearer {token}" \
  -F "file=@/path/to/image.jpg"

# Delete profile picture (auth required)
curl -X DELETE http://localhost:8081/profile/picture \
  -H "Authorization: Bearer {token}"
```

**Expected Test Results**:
- Scenario 1: GET returns UserProfile with isDefaultProfilePicture=true, profilePictureUrl=null ✓
- Scenario 2: PATCH updates fields, returns updated profile, persists after restart ✓
- Scenario 3: POST succeeds with JPEG/PNG ≤5MB, returns URL, image stored ✓
- Scenario 4: POST rejects GIF with HTTP 400 message ✓
- Scenario 5: POST rejects 6MB with HTTP 413 message ✓
- Scenario 6: DELETE reverts to default, file removed ✓

---

## Success Criteria

1. ✅ **All 38 tasks completed** with all acceptance criteria met
2. ✅ **Database migrations** run successfully, schema valid
3. ✅ **Backend endpoints** respond correctly per OpenAPI contracts (profile-endpoints.yaml)
4. ✅ **Privacy enforcement** working (private profiles blocked for non-owners)
5. ✅ **Image validation** rejects invalid formats/sizes with specific error messages
6. ✅ **Frontend screens** display profile data, allow editing, show image upload UI
7. ✅ **E2E flow** works: login → view profile → edit profile → upload image → logout/login → data persists
8. ✅ **All 6 scenarios** from spec.md pass manual testing
9. ✅ **Performance** meets targets: profile view <300ms, edit <500ms, upload <2s

---

## References & Resources

**Input Documents**:
- `/specs/005-profile-system/spec.md` - Feature specification, 6 scenarios, 8 FRs
- `/specs/005-profile-system/plan.md` - Technical implementation plan, architecture
- `/specs/005-profile-system/data-model.md` - Database schema, entity definitions
- `/specs/005-profile-system/contracts/profile-endpoints.yaml` - OpenAPI specification (4 endpoints)
- `/specs/005-profile-system/contracts/user-profile-model.md` - Data contracts, serialization
- `/specs/005-profile-system/quickstart.md` - Code templates, implementation guide

**Related Specs**:
- Spec 001: Docker Compose, static file serving infrastructure
- Spec 002: User table, database migrations pattern
- Spec 003: User authentication, JWT handling, auth middleware
- Spec 004: Core database models, Dart patterns

**Key Dependencies**:
- `backend`: `image` v4.0+, `shelf_router`, `postgres`
- `frontend`: `flutter_riverpod`, `http`, `image_picker`

**Performance Targets**:
- Profile view: <300ms (Riverpod 5-min cache)
- Profile edit: <500ms (database sync)
- Image upload: <2s (validation + processing + storage)
- Image processing: <500ms per 5MB file
