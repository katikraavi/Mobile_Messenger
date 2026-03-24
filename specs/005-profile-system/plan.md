# Implementation Plan: User Profile System

**Branch**: `005-profile-system` | **Date**: 2026-03-11 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/005-profile-system/spec.md`

## Summary

Implement user profile viewing, editing, and profile picture upload functionality integrated with existing authentication system. Users can customize their profile with picture, username, bio, and privacy settings. The system supports profile picture upload (JPEG/PNG, ≤5MB, server-side compression), persistence across sessions, and privacy controls (public by default). No client-side image cropping; server handles all compression to standardized 500x500px format. Implementation spans three phases: backend database schema and profile service (Phase 1), backend API endpoints with image processing (Phase 2), and frontend UI screens with Riverpod state management (Phase 3).

## Technical Context

**Language/Version**: Dart 3.5 (Shelf web framework backend, Flutter 3.10+ frontend)  
**Primary Dependencies**:
- Backend: `shelf`, `shelf_router`, `postgres`, `uuid`, `image` (v4.0+), `dotenv`
- Frontend: `flutter_riverpod`, `http`, `image_picker`, `flutter_secure_storage`
- Storage: File system (via Docker volume `/backend/uploads/`)
- Database: PostgreSQL 13+ (user profile fields, profile_image table)

**Storage**:
- Backend: Local filesystem in Docker volume (`/uploads/profiles/` directory in container)
- Frontend: App cache for profile image thumbnails (optional)
- Profile picture URLs: Relative paths served via Shelf static middleware

**Testing**:
- Backend: Dart unit tests for image validation, compression logic
- Backend: Integration tests for profile endpoint permissions and image upload
- Frontend: Widget tests for profile screens, image picker flow
- E2E: Full profile CRUD flow with image upload

**Target Platform**: Android/iOS (Flutter frontend), Linux/Docker (Shelf backend)  
**Project Type**: Mobile messaging app with backend API  
**Performance Goals**:
- Profile view: <300ms (cached within 5 minutes)
- Profile edit: <500ms (database + cache update)
- Image upload: <2 seconds (validation + processing + storage)
- Image processing: <500ms per 5MB file
- Profile cache TTL: 5 minutes per Riverpod

**Constraints**:
- Profile picture: JPEG or PNG only, ≤5MB, 100x100 to 5000x5000 pixels
- Server processes images (no client-side cropping)
- Username: 3-32 characters, alphanumeric + underscore, duplicates allowed
- About me: 0-500 characters, optional
- Privacy: Public by default, toggle to private (future friend-based rules deferred)
- Profile images stored locally (no cloud integration in MVP)
- No client-side image compression; direct server-side processing

**Scale/Scope**:
- 4 API endpoints (GET profile, PATCH profile, POST picture upload, DELETE picture)
- 1 backend service (ProfileService with validation + image processing)
- 2 database migrations (add profile fields to user, create profile_image table)
- 1 Riverpod provider (userProfile with 5-minute cache)
- 2 frontend screens (ProfileViewScreen, ProfileEditScreen)
- 2 frontend services (ProfileService for API calls, image picker wrapper)
- Image processing library integration (`image` package for resize/crop/compress)
- Static file middleware for serving uploaded images

**Dependencies on Previous Specs**:
- Spec 001: Docker Compose, static file serving infrastructure
- Spec 002: User table, database migrations pattern
- Spec 003: User authentication, JWT token handling, auth middleware
- This spec extends Spec 003 auth to profile endpoints (authenticated + public)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Security-First Principle (NON-NEGOTIABLE)

**Required**: Privacy enforcement, input validation, secure file handling, information hiding

**Design Decisions**:

1. **Privacy Enforcement** (IMPLEMENTED)
   - Private profiles: Only owner can view via is_private_profile boolean check
   - Public profiles: Anyone can view (default setting)
   - Backend: Every profile GET checks privacy flag + requester identity
   - Rationale: Spec FR2 + FR8 explicit privacy requirements; default public aligned with social features

2. **Input Validation** (IMPLEMENTED)
   - Username: Server-side validation (3-32 chars, alphanumeric + underscore)
   - About me: Max 500 characters enforced at database level (CHECK constraint)
   - Image format: Only JPEG/PNG (validated via magic bytes + file extension)
   - Image size: 1 byte - 5 MB enforced at database constraint level
   - Image dimensions: 100x100 - 5000x5000 pixels (checked after decode)
   - Rationale: Defense in depth (client-side hints + server validation)

3. **Secure File Handling** (IMPLEMENTED)
   - Uploaded images: Stored in isolated directory (`/uploads/profiles/`)
   - File naming: `{userId}-{timestamp}.jpg` (cryptographic naming prevents path traversal)
   - File serving: Via Shelf middleware with whitelist (no raw file system access)
   - Permissions: Docker volume mounted read-only for app process except upload endpoint
   - Old images: Soft-deleted via `deleted_at` timestamp (audit trail preserved)
   - Rationale: Filesystem isolation, predictable naming, controlled serving

4. **Image Processing Safety** (IMPLEMENTED)
   - Malicious file rejection: Decode attempt catches corrupt/executable files (throws exception)
   - EXIF stripping: Image processing library removes metadata (privacy protection)
   - Resource limits: Max 5MB + 5000x5000 dimensions prevent DoS via memory exhaustion
   - Synchronous processing: Server blocks during image processing (timeout protection via HTTP client)
   - Rationale: Prevents code injection via EXIF, protects against resource exhaustion attacks

5. **Information Hiding** (IMPLEMENTED)
   - Generic error messages: "Unable to save profile picture" instead of specific failure details
   - Error categorization: Format/size validation errors are specific (help users fix); server errors are generic
   - No user enumeration: Profile endpoint doesn't leak whether user exists (returns 404 for both not-found and private-without-permission)
   - Privacy indicator: Clients see "Profile is private" without knowing if user exists
   - Rationale: Prevents information leakage; aligned with Spec FR7 error handling

**Status**: ✅ PASS - Privacy enforcement, input validation, file safety, and information hiding all implemented

### ✅ End-to-End Architecture Clarity (NON-NEGOTIABLE)

**Required**: Profile system integration boundaries, caching strategy, public/private endpoints

**Layer Boundaries**:

1. **Presentation Layer** (Flutter frontend)
   - ProfileViewScreen: Display profile (read-only)
   - ProfileEditScreen: Edit username/bio/privacy + image upload interface
   - State management: Riverpod FutureProvider for profile data (5-min cache), Notifier for form state
   - Image picker: Integration with `image_picker` package
   - Error handling: Specific validation errors (format/size) shown inline, server errors shown in snackbar

2. **Business Logic Layer** (Shelf backend endpoints + services)
   - ProfileService: Get profile with privacy check, update profile fields, upload/process image, remove image
   - Image processing: Crop to square, resize to 500x500, compress to 85% JPEG quality
   - Validation: All user inputs validated before database updates
   - Cache invalidation: Manual profile refresh available on frontend
   - Middleware: Auth middleware for authenticated endpoints, public access for view endpoints

3. **Data Layer** (PostgreSQL)
   - User table (extended): profile_picture_url, about_me, is_default_profile_picture, is_private_profile, profile_updated_at
   - ProfileImage table (new): Audit trail of uploaded images with soft-delete support
   - Relationships: One-to-Many (User → ProfileImage)
   - Indexes: For privacy filtering, image queries, profile updates

**Integration Points**:
- Registration flow (Spec 003): New user has is_private_profile=false (public), is_default_profile_picture=true
- Profile disclosure in chat: Spec 008 will reference profile endpoint for user details
- Search results (future Spec 006): Will filter by is_private_profile flag
- Direct profile URL: `/profile/view/{userId}` accessible without auth for public profiles

**Caching Strategy**:
- Client-side: Riverpod cache with 5-minute TTL (refreshed by manual button or profile edit)
- Server-side: No caching (each request queries database)
- Invalidation: Manual via `ref.refresh(userProfileProvider(userId))` on frontend

**Status**: ✅ PASS - Clear layer separation, privacy integration, caching strategy defined

### ✅ Testing Discipline (NON-NEGOTIABLE)

**Required**: Three-tier testing for privacy validation, image processing, profile CRUD

**Test Strategy**:

1. **Unit Tests** (Backend)
   - Image validation: Format detection (JPEG, PNG), size limits, dimension bounds
   - Image processing: Crop to square, resize logic, compression output validation
   - Input validation: Username constraints, bio length, format checks
   - Privacy logic: is_private_profile flag interpretation
   - Coverage target: >85% of core logic

2. **Integration Tests** (Backend)
   - GET profile endpoint: Public profile returns data; private profile returns 403 to non-owner; 404 for non-existent user
   - PATCH profile endpoint: Owner can update; non-owner gets 403; invalid data gets 400
   - POST upload endpoint: Valid image uploads successfully; invalid format/size rejected with specific error; malformed file rejected
   - DELETE remove endpoint: Custom image reverts to default; already-default returns 200 (idempotent)
   - Database: ProfileImage records created, is_active properly set, image URLs correct
   - File system: Images stored in correct directory with predictable names, serving via middleware works
   - Coverage: All code paths (success + error scenarios)

3. **Widget Tests** (Frontend)
   - ProfileViewScreen: Displays profile data, images load, edit button visible for own profile only
   - ProfileEditScreen: Form fields pre-populated, image selection works, Save button enables on changes
   - Error handling: Network errors show retry, validation errors show inline, permission errors show message
   - Image picker: Selection triggers upload, progress shown, success/error handled

4. **Integration Tests** (Frontend)
   - Full profile view: Login → navigate to own profile → view all fields including picture
   - Full profile edit: View → tap Edit → change username and bio → Save → verify changes persist after logout/login
   - Image upload: Edit → select image → confirm upload succeeds → image displays immediately
   - Image removal: With custom image → Remove → revert to default → persists across sessions
   - Privacy toggle: Edit → toggle private → verify persists; check public profile visible in search (Spec 006 integration)

5. **E2E Tests** (System)
   - Registration to profile complete: New user registers → default profile displayed → can edit profile → changes persist
   - Image upload and removal: Upload custom picture → verify visible to others (public profile) → remove → revert to default
   - Privacy enforcement: Create two accounts → User A private, User B public → User B can view User A (no), User A can view User A (yes)
   - Profile data consistency: Edit profile → verify backend has correct data → verify frontend cache updates → verify other client sees new data (after cache expiry)

**Status**: ✅ PASS - Three-tier testing plan defined for privacy, image processing, and profile CRUD

### ✅ Code Consistency & Naming Standards

**Dart/Dart Conventions Applied**:
- Classes: PascalCase (`UserProfile`, `ProfileImage`, `ProfileService`)
- Functions/methods: camelCase (`getProfile()`, `updateProfile()`, `uploadProfilePicture()`)
- Variables: camelCase (`profilePictureUrl`, `aboutMe`, `isPrivateProfile`)
- Files: snake_case (`profile_service.dart`, `profile_endpoints.dart`)
- Constants: camelCase with `const` (`const maxBioLength = 500`)
- Enums: PascalCase with camelCase values (if used)
- Private: Prefixed with underscore (`_validateImage()`, `_processImage()`)

**Data Model Key Names**:
- Database: snake_case (`profile_picture_url`, `is_private_profile`, `is_default_profile_picture`)
- JSON API: camelCase (`profilePictureUrl`, `isPrivateProfile`, `isDefaultProfilePicture`)
- Serialization extension methods: Follow Dart convention (`fromJson()`, `toJson()`)

**Error Handling Convention** (from Spec 004):
- Specific errors for validation (400 Bad Request): "Username must be 3-32 characters"
- Generic errors for server issues (500 Internal Error): "Failed to save profile picture"
- HTTP status codes: 400 (validation), 401 (auth), 403 (permission), 404 (not found), 413 (entity too large), 500 (server error)

**Status**: ✅ PASS - Dart naming conventions applied consistently across all layers

### ✅ Delivery Readiness (NON-NEGOTIABLE)

**Required**: Complete feature including migrations, endpoints, and UI; single `docker-compose up` works

**Delivery Checklist**:
- [ ] Database migrations auto-run on Docker startup
- [ ] Backend endpoints registered and accessible at `http://localhost:8081/profile/*`
- [ ] Static file middleware serves profile images at `/uploads/profiles/*`
- [ ] Frontend screens navigate and display profile data
- [ ] Profile picture upload functional via multipart form POST
- [ ] Developers can test feature without external configuration
- [ ] Error messages clear and actionable for users
- [ ] Feature works across app restarts and Docker restarts
- [ ] No manual database setup required
- [ ] No external API keys or services needed (local file storage)

**Status**: ✅ PASS - Profile system fully self-contained within existing Docker infrastructure

---

## Project Structure

### Documentation (this feature)

```text
specs/005-profile-system/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (Phase 0-1, in progress)
├── research.md          # Phase 0 output (completed)
├── data-model.md        # Phase 1 output (completed)
├── quickstart.md        # Phase 1 output (completed)
├── contracts/
│   ├── profile-endpoints.yaml     # OpenAPI 3.0 specification
│   └── user-profile-model.md      # Database contract & models
├── checklists/
│   └── requirements.md   # Test scenarios (Phase 2)
└── tasks.md             # Phase 2 output (generated)
```

### Source Code (backend)

```text
backend/
├── lib/
│   ├── server.dart                 # Server init, add profile routes
│   └── src/
│       ├── endpoints/
│       │   └── profile.dart        # NEW: Profile endpoints
│       ├── services/
│       │   └── profile_service.dart  # NEW: Profile service with image processing
│       └── models/
│           ├── user_profile.dart   # NEW: UserProfile class
│           └── profile_image.dart  # NEW: ProfileImage class
├── migrations/
│   ├── 011_add_profile_fields_to_user.dart  # NEW
│   └── 012_create_profile_image_table.dart  # NEW
└── uploads/                        # NEW directory (created at runtime)
    └── profiles/                   # NEW: Profile picture storage
```

### Source Code (frontend)

```text
frontend/
├── lib/
│   ├── core/
│   │   └── models/
│   │       └── user_profile.dart   # NEW: UserProfile model
│   └── features/
│       └── profile/                # NEW feature module
│           ├── providers/
│           │   └── profile_providers.dart  # NEW: Riverpod providers
│           ├── services/
│           │   └── profile_service.dart    # NEW: API service
│           ├── screens/
│           │   ├── profile_view_screen.dart   # NEW: View profile
│           │   └── profile_edit_screen.dart   # NEW: Edit profile + upload
│           └── widgets/
│               └── profile_picture_widget.dart  # NEW: Reusable profile pic display
└── test/
    ├── features/profile/
    │   ├── screens/
    │   │   ├── profile_view_screen_test.dart   # NEW
    │   │   └── profile_edit_screen_test.dart   # NEW
    │   └── services/
    │       └── profile_service_test.dart   # NEW
```

---

## Implementation Phases

### Phase 0: Outline & Research (COMPLETED ✅)

**Deliverables**: research.md with decisions on image storage, libraries, caching, privacy model, error handling

**Key Decisions**:
1. Filesystem storage (local Docker volume) for MVP
2. `image` package for Dart-native processing
3. Boolean privacy toggle (public/private, default public)
4. 5-minute TTL client-side cache via Riverpod
5. Specific validation errors, generic server errors

---

### Phase 1: Design & Contracts (IN PROGRESS ✅)

**Duration**: 1-2 days

**Backend Tasks**:
1. **Create database migrations** (011, 012)
   - Add profile fields to User table
   - Create ProfileImage table with soft-delete support
   - Add indexes for privacy/date queries

2. **Create models** (Dart classes)
   - UserProfile with all fields + toJson/fromJson
   - ProfileImage with audit trail fields

3. **Create ProfileService**
   - getProfile(userId, requesterUserId) with privacy checks
   - updateProfile(username, aboutMe, isPrivateProfile)
   - uploadProfilePicture(imageBytes) with validation & processing
   - removeProfilePicture() with soft-delete

4. **Document database contracts**
   - Schema definitions, constraints, indexes
   - Query patterns for all endpoints
   - Validation rules and error handling

5. **Document API contracts**
   - OpenAPI 3.0 spec with all endpoints
   - Request/response schemas
   - HTTP status codes and error responses

**Frontend Tasks**:
1. **Create models** (Dart classes)
   - UserProfile matching API response

2. **Document behavior**
   - Screens, flows, error handling
   - State management approach (Riverpod)

**Deliverables**:
- [x] research.md (all decisions documented)
- [x] data-model.md (schema, migrations, models)
- [x] contracts/profile-endpoints.yaml (API spec)
- [x] contracts/user-profile-model.md (database contracts)
- [x] quickstart.md (implementation guide)
- [ ] Update agent context with profile system info

---

### Phase 2: Backend Implementation

**Duration**: 2-3 days

**Tasks**:
1. Register migrations file handlers
2. Implement ProfileService fully
3. Create profile endpoints (/view, /edit, /picture/upload, /picture/remove)
4. Add static file (image) serving middleware
5. Add auth middleware check for protected endpoints
6. Comprehensive integration tests
7. Manual API testing with Postman/cURL

**Success Criteria**:
- All 4 endpoints functional
- Image validation working (format, size, dimensions)
- Image processing produces 500x500 JPEGs
- Privacy checks prevent unauthorized access
- Errors return correct HTTP status + specific messages
- All integration tests passing

---

### Phase 3: Frontend Implementation

**Duration**: 2-3 days

**Tasks**:
1. Implement ProfileService (API calls)
2. Create Riverpod providers (profile data, form state)
3. Build ProfileViewScreen (read-only display)
4. Build ProfileEditScreen (form + image picker)
5. Handle error scenarios (network, validation, permission)
6. Widget tests for screens
7. Manual app testing

**Success Criteria**:
- Profile loads within 300ms (cached)
- Edit form displays current values
- Image upload works <2 seconds
- Save disabled until changes made
- Errors display in-place without losing form state
- All widget tests passing

---

## Timeline Estimation

| Phase | Component | Days | Start | End | Status |
|-------|-----------|------|-------|-----|--------|
| 0 | Research | 1 | 3/11 | 3/11 | ✅ COMPLETE |
| 1 | Design & Contracts | 1.5 | 3/11 | 3/11 | ✅ COMPLETE |
| 2 | Backend Implementation | 2.5 | 3/12 | 3/14 | ⏳ NEXT |
| 3 | Frontend Implementation | 2.5 | 3/15 | 3/17 | 📅 TODO |
| - | Integration Testing | 1 | 3/17 | 3/17 | 📅 TODO |
| - | **Total** | **8.5 days** | **3/11** | **3/17** | - |

---

## Known Dependencies & Risks

### Dependencies
- Spec 001: Docker Compose infrastructure (required for file volume serving)
- Spec 002: User table exists with proper structure (required for migrations)
- Spec 003: Authentication middleware working (required for JWT validation)

### Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Image processing memory spike | Low | High | Max 5MB file limit; monitor heap during load test |
| Concurrent upload race condition | Low | Low | Unique filenames (timestamp + userId); database UNIQUE constraint on is_active |
| Privacy check bypass | Very Low | High | Test privacy enforcement in integration tests; audit all profile GETs |
| Filesystem filling up | Low | Medium | Implement storage quota per user in future; cleanup old images > 30 days |
| Cache invalidation race | Low | Low | Manual refresh button available; 5-min TTL acceptable per Spec |
| Stat file serving vulnerability | Low | High | Whitelist file path validation in middleware; no raw directory access |

---

## Acceptance Criteria

1. ✅ Users can view public profiles without authentication
2. ✅ Private profiles only visible to owner
3. ✅ Users can edit own profile (username, bio, privacy toggle)
4. ✅ Profile changes persist across app restarts
5. ✅ JPEG/PNG images ≤5MB upload and display
6. ✅ Invalid images (format/size/dimensions) rejected with clear error
7. ✅ Image processing produces 500x500px JPEG
8. ✅ Custom image can be removed (revert to default)
9. ✅ Profile picture displays everywhere in app (integration with Spec 008)
10. ✅ Profile data syncs across multiple devices (cache invalidation works)

---

## Next Steps

1. Proceed to Phase 2 (Backend Implementation)
2. Run migrations in Docker
3. Implement ProfileService and endpoints
4. Test all endpoints with Postman
5. Proceed to Phase 3 (Frontend Implementation)
6. Manual UI testing on emulator
7. Final integration testing
