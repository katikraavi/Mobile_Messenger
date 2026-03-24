# Phase 0 Research: User Profile System

**Date**: 2026-03-11  
**Feature**: 005-profile-system  
**Status**: Research Complete

## Overview

This document captures research findings and design decisions for the profile system, resolving unknowns about image storage strategy, image processing libraries, privacy permission model, caching approach, and error handling patterns.

---

## Research Question 1: Image Storage Strategy

### Question
**Should profile pictures be stored on the filesystem or in cloud storage (S3, GCS, etc.)?**

### Research Findings

#### Option A: Filesystem Storage (Chosen)
- **Approach**: Store images in `/backend/uploads/profiles/` directory with Docker volume mapping
- **Pros**:
  - No external cloud dependency; everything runs in Docker
  - Faster local development iteraton
  - No API key management or additional cloud account setup
  - Cost-free for local development and small-scale deployments
  - Simple backup strategy (volume backup = complete image backup)
- **Cons**:
  - Not horizontally scalable (multi-server deployments need shared NFS/object storage)
  - Requires volume backup strategy for production (not implemented in this feature)
  - Static file serving requires explicit Shelf middleware or separate web server

#### Option B: Cloud Storage (AWS S3, Google Cloud Storage)
- **Approach**: Upload directly to S3/GCS with signed URLs or presigned upload URLs
- **Pros**:
  - Fully scalable for production
  - CDN integration available
  - Automatic replication and disaster recovery
- **Cons**:
  - Adds deployment complexity (requires AWS/GCS account, credentials)
  - Additional costs (storage, egress bandwidth)
  - Scope creep beyond current feature (deferred to future)

**Decision**: **Filesystem storage** for MVP (Spec 005). Future Spec 010+ can migrate to cloud storage with minimal refactoring (URL scheme remains consistent).

**Rationale**: 
- Simplifies local development setup
- Aligns with Spec 001 goal (single `docker-compose up` starts everything)
- 5MB max image size per user, modest storage footprint
- Easy migration path to S3/GCS via URL indirection

---

## Research Question 2: Image Processing & Compression Library

### Question
**What Dart library should handle image compression and square cropping on the backend?**

### Research Findings

#### Option A: `image` package (Chosen)
- **Package**: `image: ^4.0.0` (pub.dev)
- **Features**:
  - Pure Dart image processing (JPEG, PNG, GIF, WebP, BMP support)
  - Resize/crop/compress operations
  - EXIF metadata stripping (privacy)
  - No native dependency compilation needed
- **Example Usage**:
  ```dart
  import 'package:image/image.dart' as img;
  
  List<int> compressAndCrop(List<int> imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw InvalidImageError();
    
    // Crop to square (center crop)
    final size = min(image.width, image.height);
    final left = (image.width - size) ~/ 2;
    final top = (image.height - size) ~/ 2;
    final cropped = img.copyCrop(image, x: left, y: top, width: size, height: size);
    
    // Resize to 500x500
    final resized = img.copyResize(cropped, width: 500, height: 500);
    
    // Encode as JPEG (85% quality)
    return img.encodeJpg(resized, quality: 85);
  }
  ```
- **Pros**:
  - Pure Dart, no native dependency compilation
  - Fast processing (< 500ms for 5MB image)
  - Well-maintained, widely used
- **Cons**:
  - Memory usage during processing (5MB image → ~5-10MB in memory)

#### Option B: FFmpeg (via `ffmpeg_kit_flutter`)
- **Approach**: Shell out to FFmpeg native library
- **Pros**: Highly optimized, production-proven
- **Cons**: Requires native dependency compilation, Linux FFmpeg binary in backend Docker (performance overkill for this use case)

#### Option C: Async processing queue (Job queue approach)
- **Approach**: Queue image processing in background job (future enhancement)
- **Pros**: No blocking on user request; better UX for slow networks
- **Cons**: Adds complexity; out of scope for MVP

**Decision**: **`image` package** for synchronous server-side processing in this feature.

**Rationale**:
- Pure Dart simplifies deployment and Docker image size
- 500ms latency acceptable per Spec FR4 (target 2 seconds for upload)
- Sufficient for MVP scale (single backend instance)
- Future: Queue-based processing for production scale (additional Spec)

---

## Research Question 3: Privacy Permission Model

### Question
**How should "can view profile" be determined when a profile is private?**

### Research Findings

#### Option A: Simple Boolean Toggle (Chosen for MVP)
- **Approach**:
  - Profile has `is_private: BOOLEAN` field
  - Public profiles (is_private = false): Anyone can view via `/profile/{userId}`
  - Private profiles (is_private = true): Only the owner can view
  - Friends/contacts: Deferred to future feature (Spec 007+)
- **Rationale**:
  - Simplicity: Single boolean, no friend table dependency
  - MVP-appropriate: Covers 80% of use cases
  - Extensible: Can add friend-based rules later
- **Implementation**:
  ```dart
  // Backend endpoint
  Future<Profile> getProfile(String userId) async {
    final profile = await profileService.getProfile(userId);
    
    // Check visibility
    if (profile.isPrivate && profile.userId != authenticatedUserId) {
      throw PermissionDenied('Profile is private');
    }
    
    return profile;
  }
  ```

#### Option B: Friend-Based ACL (Out of Scope for MVP)
- **Approach**: Check if viewer is friend of profile owner
- **Pros**: More granular privacy
- **Cons**: Requires friend table (Spec 007+ dependency), adds complexity
- **Deferred**: Implement in future spec after friend system complete

#### Option C: Block List Model
- **Approach**: Maintain explicit "blocked" relationships
- **Cons**: Not needed for MVP; empty feature (won't block anyone initially)
- **Deferred**: Post-MVP enhancement

**Decision**: **Boolean toggle** (public/private) for MVP. Default: **public** (all new profiles are public).

**Rationale**:
- Matches Spec requirement ("public/private, default public")
- No external table dependencies
- Easy to query (`WHERE is_private = false` for search results)
- Extensible to friends model later

---

## Research Question 4: Profile Data Caching Strategy

### Question
**Should profile data be cached on frontend? If so, for how long?**

### Research Findings

#### Option A: Cache with TTL (Chosen)
- **Approach**:
  - Client-side cache (Riverpod state) with 5-minute TTL
  - Own profile refreshes immediately after edit
  - Other users' profiles cached for 5 minutes (sufficient freshness per Spec FR6 "visible to other users within 2 seconds")
  - Manual refresh button for forced cache invalidation
- **Cache Key**: `{userId}` 
- **Invalidation Triggers**:
  - User edits own profile → immediate invalidation + backend sync
  - Time-based (5 min TTL)
  - Manual "refresh" button
- **Example**:
  ```dart
  @riverpod
  Future<Profile> userProfile(UserProfileRef ref, String userId) async {
    final profileService = ref.watch(profileServiceProvider);
    return profileService.getProfile(userId);
  }
  
  // On frontend:
  final profile = await ref.watch(userProfile(userId).future);
  // Cached for 5 minutes, manually refreshable
  ```

#### Option B: Always Fetch Fresh
- **Approach**: No caching, always hit backend
- **Pros**: Guaranteed consistency
- **Cons**: Slower UX, unnecessary backend load
- **Not chosen**: Suboptimal UX

#### Option C: Server Push (WebSocket)
- **Approach**: Backend pushes profile updates to subscribed clients via WebSocket
- **Pros**: Real-time updates without polling
- **Cons**: Out of scope for MVP (requires WebSocket infrastructure beyond Spec 001)
- **Deferred**: Post-MVP enhancement

**Decision**: **Client-side cache with 5-minute TTL** (Riverpod managed state).

**Rationale**:
- Spec FR6 requires visibility within 2 seconds (cache miss + fetch < 2s achievable)
- Reduces backend load for repeated profile views
- Riverpod's built-in invalidation handles TTL
- Manual refresh available for user control

---

## Research Question 5: Image Upload Error Handling Strategy

### Question
**How should validation errors be reported?Type of error vs. generic message?**

### Research Findings

#### Error Categories

1. **Format Validation Errors**
   - Error: Unsupported file type (GIF, BMP, WebP, etc.)
   - Response: 400 Bad Request, specific message
   - Message: `"Only JPEG and PNG formats are supported"`
   - Frontend: Show inline error, preserve form state

2. **Size Validation Errors**
   - Error: File > 5MB
   - Response: 413 Payload Too Large
   - Message: `"File must be smaller than 5MB"`
   - Frontend: Show inline error, preserve form state

3. **Dimension Validation Errors**
   - Error: Image < 100x100 or > 5000x5000 pixels
   - Response: 400 Bad Request
   - Message: `"Image dimension must be between 100x100 and 5000x5000 pixels"`
   - Frontend: Show inline error

4. **Image Corruption/Parse Error**
   - Error: File claims to be JPEG but invalid structure
   - Response: 400 Bad Request
   - Message: `"Unable to process image file. Please ensure it's a valid JPEG or PNG."`
   - Frontend: Show generic error (user can retry)

5. **Database/Storage Errors**
   - Error: Database insert fails, filesystem write fails
   - Response: 500 Internal Server Error
   - Message: `"Failed to save profile picture. Please try again."` (generic to user)
   - Backend: Log full error for debugging
   - Frontend: Show retry button, preserve form state

6. **Network/Timeout Errors**
   - Error: Upload times out mid-transfer
   - Response: 408 Request Timeout or connection reset
   - Frontend: Show "Network error" message + retry button
   - UX: Client can resume or restart upload

#### Error Handling Pattern
- **Client-Side Validation**: Check file size/format before upload (quick feedback)
- **Server-Side Validation**: Always re-validate (security)
- **Specific User Errors** (400-level): Clear message to help user fix
- **Server Errors** (500-level): Generic message; detailed logging for debugging
- **Form State Preservation**: Don't lose other form fields on validation error

#### Code Example
```dart
// Backend validation
Future<String> uploadProfilePicture(String userId, List<int> imageBytes) async {
  // Check size
  if (imageBytes.length > 5 * 1024 * 1024) {
    throw HttpException(413, 'File must be smaller than 5MB');
  }
  
  // Detect format
  final format = detectImageFormat(imageBytes); // 'jpeg', 'png', null
  if (format == null) {
    throw HttpException(400, 'Only JPEG and PNG formats are supported');
  }
  
  // Decode and validate dimensions
  final image = img.decodeImage(imageBytes);
  if (image == null || image.width < 100 || image.width > 5000) {
    throw HttpException(400, 'Image dimension must be between 100x100 and 5000x5000 pixels');
  }
  
  // Process and store
  try {
    final processed = processImage(image);
    final filename = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await storageService.saveFile('profiles/$filename', processed);
    return '/uploads/profiles/$filename';
  } catch (e) {
    logger.error('Profile upload failed', e);
    throw HttpException(500, 'Failed to save profile picture. Please try again.');
  }
}

// Frontend
try {
  final imageBytes = await _pickImage();
  
  // Quick client-side validation
  if (imageBytes.length > 5 * 1024 * 1024) {
    showError('File too large (max 5MB)');
    return;
  }
  
  // Upload with retry
  final url = await profileService.uploadProfilePicture(imageBytes);
  setState(() => _profilePictureUrl = url);
  showSuccess('Profile picture updated');
} on HttpException catch (e) {
  showError(e.message); // Specific message
  // Form state preserved; user can retry
} catch (e) {
  showError('Upload failed. Please try again.');
}
```

**Decision**: **Specific, actionable error messages for user validation errors; generic messages for server errors.**

**Rationale**:
- Spec Scenarios 4-5 require specific format/size error messages
- Generic server errors prevent information leakage
- Form state preservation improves UX
- Aligns with web standards (REST status codes)

---

## Research Question 6: Image Serving & URL Scheme

### Question
**How should uploaded images be served to clients? CDN URL vs. signed URL vs. direct path?**

### Research Findings

#### Option A: Direct Path URL (Chosen for MVP)
- **Approach**: Return simple relative/absolute file path; Shelf static file middleware serves
- **URLs**: `/uploads/profiles/user-123-1234567890.jpg`
- **Implementation**: Static middleware in Shelf server
- **Pros**: Simple, no complexity, images immediately available
- **Cons**: Not scalable to multi-server deployments (future concern)
- **Code**:
  ```dart
  var handler = const Pipeline()
    .addMiddleware(logRequests())
    .addMiddleware(_staticFileMiddleware('/uploads'))
    .addHandler(_router);
  
  // Serve static files from /uploads directory
  Handler _staticFileMiddleware(String basePath) => (request) async {
    final filePath = '/backend/uploads${request.url.path}';
    final file = File(filePath);
    if (await file.exists() && await file.stat().type == FileSystemEntityType.file) {
      return Response.ok(await file.readAsBytes(),
        headers: {'content-type': 'image/jpeg'});
    }
    return Response.notFound('Not found');
  };
  ```

#### Option B: Signed/Presigned URLs (Out of scope)
- **Approach**: Generate time-limited signed URLs
- **Pros**: Access control, expiring links
- **Cons**: Additional complexity, overkill for public profiles (MVP)
- **Deferred**: When access control becomes necessary

#### Option C: CDN URL (AWS CloudFront, etc.)
- **Approach**: Integrate with AWS S3 + CloudFront
- **Cons**: Requires cloud infrastructure (out of scope for Spec 005)
- **Deferred**: Spec 010+ (production deployment)

**Decision**: **Direct file path URL** served via Shelf static middleware.

**Rationale**:
- Simplest implementation (Docker volume + Shelf middleware)
- Sufficient for MVP + local development
- Easy migration to CDN later (URL scheme abstraction)
- Consistent with Spec 001 philosophy (self-contained Docker setup)

---

## Research Question 7: Profile Metadata & Audit Trail

### Question
**Should profile changes be audited? When was it last updated?**

### Research Findings

#### Audit Trail Approac (Chosen)
- **Approach**: Track `updated_at` timestamp on profile and image entities
- **Fields**:
  - User: `updated_at` (when profile last changed)
  - ProfileImage: `uploaded_at` (when image was uploaded)
- **Use Cases**:
  - Sort profiles by "recently updated" (social features)
  - Detect stale cache (compare to client-side timestamp)
  - Debugging (who changed what when)
- **No separate audit table**: MVP scope (can add full audit log in future)

**Decision**: **Include `updated_at` timestamp on User and ProfileImage tables.**

**Rationale**:
- Minimal overhead (one timestamp field)
- Enables future sorting/filtering by recency
- Helpful for debugging stale cache issues
- Aligns with Spec 002 pattern (messages have `created_at`, `edited_at`)

---

## Research Question 8: Username Uniqueness Implications

### Question
**If usernames can be duplicated, how does this affect search, mentions, and display?**

### Research Findings

#### Decision Summary
Per Spec FR5: "Username uniqueness: Allow duplicate usernames. Users are primarily identified by user ID."

#### Implications for Profile System

1. **Display Strategy**:
   - View own profile: Show username only
   - View others' profiles in chat: Show "username (#userId)" for disambiguation
   - Search results: Display "username (ID: abc123)" to distinguish duplicates
   - Profile screen: Display full user ID in footer for power users

2. **Database Impact**:
   - Users.username: Remove UNIQUE constraint (from Spec 002)
   - Index: Still indexed for search queries (allow duplicates in index)
   - Search Query: `SELECT * FROM "user" WHERE LOWER(username) LIKE LOWER('%query%')` (can return multiple rows)

3. **Frontend Impact**:
   - Profile card: Show "username" prominently, "User ID: abc123" in smaller text
   - Mention autocomplete: Show "username (ID)" under suggestions
   - No breaking changes to existing UI (Spec 003 already handles user ID)

**Decision**: **Keep Spec 002 updated** (remove UNIQUE constraint on username if not already done).

**No code changes needed for Spec 005**: Profile system agnostic to uniqueness (uses user_id as PK always).

**Rationale**:
- Spec 002 should have removed UNIQUE before Spec 005 implementation
- Profile system already user-ID-centric
- Search/display concerns belong to separate specs (006 Search, 008 Chat List)

---

## Summary of Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Image Storage | Filesystem in Docker volume | MVP simplicity; cloud migration path clear |
| Image Processing | `image` package (Dart) | Pure Dart; no native dependencies; sufficient performance |
| Privacy Model | Boolean toggle (public/private) | Simple; MVP-appropriate; extensible to friends model |
| Caching | Riverpod 5-min TTL | Balances freshness + performance; manual refresh available |
| Error Handling | Specific user errors, generic server errors | UX improvement; security (no info leakage) |
| Image URLs | Direct path via Shelf middleware | Simple; self-contained; CDN migration path clear |
| Audit Trail | `updated_at` timestamp | Minimal overhead; enables future features |
| Username Uniqueness | Handle in search/display (deferred specs) | Spec 005 integrates with existing Spec 002 model |

---

## Dependencies & Integration Points

1. **Spec 001**: Docker Compose infrastructure, static file serving (middleware needed)
2. **Spec 002**: User table (no changes needed), ProfileImage entity (new)
3. **Spec 003**: Authentication (profile endpoints require JWT)
4. **Spec 005**: New profile endpoints, database migrations (image table)
5. **Spec 006**: Search (future integration with profile search)

---

## Estimated Implementation Complexity

- **Backend Image Processing**: Medium (image library learning curve)
- **Backend File Storage**: Low (standard middleware)
- **Database Schema**: Low (straightforward table + index)
- **API Endpoints**: Medium (4 endpoints + validation)
- **Frontend UI**: Medium (image picker, upload progress, error handling)
- **Testing**: Medium (image validation scenarios; file I/O mocking)

---

## Known Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Image processing memory spike | OOM on 5MB+ uploads | Limit max file size 5MB; monitor memory during load testing |
| Filesystem filling up | Disk saturation | Implement storage quota per user; cleanup old versions |
| Concurrent image uploads | File I/O contention | Use unique filenames (timestamp + userId); Shelf handles concurrency |
| Cache invalidation race | Stale data visible | Manual refresh button; server-side TTL boundary enforcement |
| Private profile bypass | Security issue | Check `is_private && userId != requester` on every profile GET |

---

## Next Steps

1. **Data Model Phase**: Define database schema, migrations (data-model.md)
2. **API Contracts**: Define endpoints, request/response formats (contracts/)
3. **Quickstart**: Code examples for implementation (quickstart.md)
4. **Implementation**: Backend endpoints, frontend screens (Phases 1-2)
