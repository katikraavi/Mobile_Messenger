# Implementation Plan: User Profile System

**Branch**: `016-user-profile` | **Date**: March 13, 2026 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/016-user-profile/spec.md`

**Note**: Planning phase for Flutter mobile messenger profile feature with image upload, validation, and privacy controls.

## Summary

Users can create and customize their profile with a picture, username, and bio. The profile is visible to other users in the messenger and persists across sessions. This feature includes image upload with validation (JPEG/PNG, ≤5MB), compression to 500x500px, profile editing, privacy controls, and optimistic UI updates for better UX. Profile data loads immediately after login and reflects changes to other users within 2 seconds.

## Technical Context

**Language/Version**: Dart/Flutter 3.12.0+  
**Primary Dependencies**: Riverpod 2.4.0, image_picker 1.0.0, flutter_secure_storage 9.0.0  
**Storage**: PostgreSQL (backend profiles), local secure storage (auth tokens/credentials)  
**Testing**: Flutter widget/integration tests, mock backend responses  
**Target Platform**: Android 8.0+, iOS 12.0+, Web (future)  
**Project Type**: Mobile app (cross-platform)  
**Performance Goals**: Profile loads 500ms, images display within 2s, smooth edit transitions  
**Constraints**: Max 5MB images, 500x500px server compression, offline profile cache support  
**Scale/Scope**: 7 user stories, 20 functional requirements, 9 UI/UX patterns across profile system

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Security-First | ✅ PASS | Profile data encrypted at rest on backend; secure auth tokens required for API access; sensitive profile fields handled per cryptography library standards |
| II. End-to-End Architecture Clarity | ✅ PASS | Clear separation: Flutter UI layer → HTTP/WebSocket API layer → Serverpod backend → PostgreSQL. Profile data flows explicitly through defined contracts |
| III. Testing Discipline | ⚠️ NEEDS VALIDATION | Feature has specification with acceptance scenarios; tests TBD during Tasks phase (unit tests for validators, widget tests for UI, integration tests for edit/save flow) |
| IV. Code Consistency & Naming | ✅ PASS | Dart naming conventions applied throughout: snake_case files (profile_edit_screen.dart), PascalCase classes (ProfileEditScreen), camelCase methods (setProfile(), handleImageUpload()) |
| V. Delivery Readiness | ✅ PASS | Backend docker-compose already operational; Android builds tested; profile feature integrates into existing navigation (bottom nav bar) |

**Gate Result**: ✅ PASS - No blocking violations. All core principles satisfied or addressed in subsequent phases.

## Project Structure

### Documentation (this feature)

```text
specs/016-user-profile/
├── spec.md               # Feature specification (complete)
├── plan.md               # This file (planning output)
├── research.md           # Phase 0: Research findings (PENDING)
├── data-model.md         # Phase 1: Data contracts (PENDING)
├── quickstart.md         # Phase 1: Developer quickstart (PENDING)
├── contracts/            # Phase 1: API/UI contracts (PENDING)
│   ├── api-profile-endpoints.md
│   ├── ui-profile-components.md
│   └── state-management.md
└── tasks.md              # Phase 2: Implementation tasks (PENDING - /speckit.tasks)
```

### Source Code Structure (Mobile App - Flutter)

```text
frontend/
├── lib/
│   ├── core/              # Reusable utilities, constants
│   ├── features/
│   │   ├── auth/          # Authentication (existing)
│   │   ├── search/        # Search (existing)
│   │   └── profile/       # PROFILE FEATURE (NEW)
│   │       ├── models/
│   │       │   ├── user_profile.dart
│   │       │   └── profile_image.dart
│   │       ├── screens/
│   │       │   ├── profile_view_screen.dart
│   │       │   └── profile_edit_screen.dart
│   │       ├── providers/
│   │       │   ├── user_profile_provider.dart
│   │       │   └── profile_form_state_provider.dart
│   │       ├── services/
│   │       │   └── profile_api_service.dart
│   │       └── widgets/
│   │           ├── profile_picture_widget.dart
│   │           ├── image_upload_widget.dart
│   │           └── profile_form_fields.dart
│   └── services/          # Global services (API, storage, auth)
├── test/
│   ├── unit/
│   │   └── features/profile/        # Profile unit tests (validators, utilities)
│   ├── widget/
│   │   └── features/profile/        # Profile widget tests (UI rendering)
│   └── integration/
│       └── profile_flow_test.dart   # Edit/upload/view flow integration test
└── pubspec.yaml           # Dependencies (image_picker, riverpod, flutter_secure_storage)

backend/
├── lib/
│   └── src/
│       ├── models/
│       │   └── user_profile.dart    # Database model
│       ├── services/
│       │   └── profile_service.dart # Business logic
│       └── endpoints/
│           └── profile_endpoint.dart # HTTP API & WebSocket handlers
└── migrations/
    └── 014_create_profile_tables.dart (FUTURE: per spec)
```

**Structure Decision**: Mobile-first Flutter architecture using Riverpod state management. Profile feature encapsulates models, screens, providers, services, and widgets. Backend provides HTTP endpoints for CRUD operations and image handling. Tests organized by type (unit/widget/integration) following Flutter conventions.

## Complexity Tracking

> No Constitution violations requiring justification. Feature design aligns with all core principles.

---

## Phase 0: Research & Clarifications

**Status**: ✅ COMPLETE  
**Output**: `research.md`

**Findings**:
- Image handling: image_picker 1.0.0 (standard Flutter package)
- State management: Riverpod 2.4.0 with StateNotifier pattern
- Validation: Dual-layer (client + server)
- UI Updates: Optimistic pattern per clarification Q4
- Caching: 5-minute TTL with manual refresh
- Privacy: MVP toggle + future permission layer
- API: REST with multipart image upload

**All Clarifications Resolved**:
- ✅ Q1: Private profile visibility (lock icon, no backend filtering in MVP)
- ✅ Q2: Username/bio defaults (auto-populate username, empty bio)
- ✅ Q3: Image compression (500x500px square)
- ✅ Q4: Image URL update timing (optimistic on success)

**Ready for**: Phase 1 design

---

## Phase 1: Design & Contracts

**Status**: ✅ COMPLETE  
**Output**: `data-model.md`, `quickstart.md`, `contracts/` directory

### Data Model
**Location**: `data-model.md`

**Core Entities**:
- User (extended with profile fields: profilePictureUrl, aboutMe, isPrivateProfile)
- ProfileImage (new: metadata for uploaded images)
- UserProfileState (Riverpod: read-only display data)
- ProfileFormState (Riverpod: editable form state)

**Success Metrics**:
- Profile loads: 500ms
- Image upload: 2 seconds
- Changes visible to others: 2 seconds

### API Contracts
**Location**: `contracts/api-endpoints.md`

**Four REST Endpoints**:
1. `GET /api/profile/:userId` - Fetch profile
2. `PUT /api/profile` - Update text fields + privacy
3. `POST /api/profile/picture` - Upload image (multipart)
4. `DELETE /api/profile/picture` - Remove custom image

**Response Codes**: 200 (success), 400 (validation), 413 (file too large), 401 (auth), 403 (forbidden), 404 (not found)

**Rate Limiting**: GET (60/min), PUT (10/min), POST (5/min), DELETE (10/min)

### UI Component Contracts
**Location**: `contracts/ui-components.md`

**Components**:
- ProfileViewScreen: Display read-only profile (own or other user's)
- ProfileEditScreen: Edit form with all fields + image upload
- ImageUploadWidget: Reusable image picker with validation feedback
- ProfilePictureWidget: Display-only with default avatar fallback

**Form States**: Loading, Error, Valid, Dirty, Saving, Success

### State Management Contracts
**Location**: `contracts/state-management.md`

**Providers**:
- `userProfileProvider` (FutureProvider): Fetch and cache profile data
- `profileFormStateProvider` (StateNotifierProvider): Manage edit form state

**StateNotifier Methods**: updateUsername, updateBio, setImage, removeImage, togglePrivacy, save, reset, validate

**Validation Functions**: Shared between client and server (username 3-32 chars, bio 0-500 chars, image format/size/dimensions)

### Developer Quickstart
**Location**: `quickstart.md`

**10-Day Implementation Plan**:
- Days 1-2: Data models & API contracts
- Days 2-3: Backend API endpoints
- Days 3-4: Frontend HTTP client
- Days 4-5: Form state management (Riverpod)
- Days 5-7: UI components (ProfileViewScreen, ProfileEditScreen, ImageUploadWidget)
- Days 7-8: Image handling & validation
- Days 8-9: Testing (unit, widget, integration)
- Days 9-10: Edge cases, performance, accessibility

**Code Patterns Included**: Form state with Riverpod, client-side image validation, optimistic image updates, unit/widget test examples

---

## Phase 1 Re-evaluation: Constitution Check

*GATE: Re-check after Phase 1 design*

| Principle | Status | Resolution |
|-----------|--------|-----------|
| I. Security-First | ✅ PASS | All API calls require Bearer token; image validation prevents malicious files; profile data encrypted at rest per backend config |
| II. End-to-End Architecture Clarity | ✅ PASS | Clear layering: Flutter UI → HTTP API → Serverpod backend → PostgreSQL; all data flows explicit in contracts |
| III. Testing Discipline | ✅ PASS | Test plan includes unit (validators), widget (form rendering), integration (edit/save flow); acceptance scenarios defined |
| IV. Code Consistency & Naming | ✅ PASS | Dart conventions applied: snake_case files, PascalCase classes, camelCase methods throughout all contracts |
| V. Delivery Readiness | ✅ PASS | Backend ready via docker-compose; Android builds tested; feature integrates into existing navigation |

**Gate Result**: ✅ PASS - Feature design ready for implementation phase

---

## Deliverables Summary

### Documentation Generated
✅ plan.md (this file) - Complete planning document  
✅ research.md - Phase 0 research with 7 finding sections  
✅ data-model.md - Core entities, state models, API contracts, validation rules, data flows, database schema  
✅ quickstart.md - 10-day implementation plan with code patterns and debugging tips  
✅ contracts/api-endpoints.md - 4 REST endpoints with request/response examples (20+ examples)  
✅ contracts/ui-components.md - 4 UI components with visual layouts, states, interactions  
✅ contracts/state-management.md - Riverpod providers, StateNotifier methods, usage patterns, test contracts

### File Structure Ready
```
frontend/lib/features/profile/
├── models/ ← Ready for implementation
├── screens/ ← ProfileViewScreen & ProfileEditScreen templates
├── providers/ ← Riverpod provider structure defined
├── services/ ← ProfileApiService contract defined
└── widgets/ ← Image upload & picture widget defined

backend/lib/src/
├── endpoints/profile_endpoint.dart ← 4 endpoints specified
├── services/profile_service.dart ← Business logic contract
└── models/ ← User + ProfileImage models specified
```

### Feature Branch
✅ Branch: `016-user-profile` (per constitution workflow)  
✅ All documentation committed and ready for team handoff

---

## Recommendations for Implementation Team

1. **Start with Backend** (Days 1-3):
   - Create ProfileImage table migration
   - Implement ProfileService business logic
   - Implement 4 REST endpoints with validation
   - Test with Postman/curl (examples in api-endpoints.md)

2. **Frontend Models & API Client** (Days 3-5):
   - Create Dart models and serializers
   - Create ProfileApiService HTTP client
   - Test API integration with backend

3. **State Management** (Days 5-6):
   - Implement Riverpod providers and StateNotifier
   - Test state transitions and validation

4. **UI Implementation** (Days 6-8):
   - Build ProfileViewScreen, ProfileEditScreen, ImageUploadWidget
   - Integrate with Riverpod providers
   - Style per existing app theme (MD3)

5. **Testing & Polish** (Days 8-10):
   - Unit tests for validation functions
   - Widget tests for form rendering
   - Integration test for full edit flow
   - Edge case handling (permissions, network, validation)

6. **Before Merge**:
   - All tests passing
   - Android APK builds successfully
   - Code review approved (Constitution Check verified)
   - Manual testing on emulator: profile loads <500ms, images <2s
   - Backend docker-compose starts cleanly

---

## Next Phase

**Phase 2** (Post-Planning): Implementation Tasks
- Run `/speckit.tasks` to generate `tasks.md` with actionable task breakdown
- Tasks organized by dependency order (backend → frontend → integration)
- Each task includes acceptance criteria, test requirements, dependencies
- Track progress against 10-day timeline

---

*Planning Complete - Feature Ready for Implementation - March 13, 2026*
