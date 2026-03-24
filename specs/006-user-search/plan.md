# Implementation Plan: User Search

**Branch**: `006-user-search` | **Date**: 2026-03-12 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/006-user-search/spec.md`

## Summary

Implement user search functionality allowing users to discover other users by username or email address. The system includes query validation, case-insensitive search via database indexes, result pagination, and privacy filtering (unverified users excluded). No client-side search logic; all queries use backend API with efficient database indexing. Implementation spans three phases: database optimization (Phase 1), backend search service and endpoints (Phase 2), and frontend search UI with debounce (Phase 3).

## Technical Context

**Language/Version**: Dart 3.5 (Shelf web framework backend, Flutter 3.10+ frontend)  
**Primary Dependencies**:
- Backend: `shelf`, `shelf_router`, `postgres`, `uuid`, `dotenv`
- Frontend: `flutter_riverpod`, `http`, `go_router`
- Database: PostgreSQL 13+ (case-insensitive LOWER() indexes on username/email, is_verified filter)

**Database Optimization**:
- Backend: PostgreSQL LOWER() function indexes for case-insensitive search
- Indexes on username, email, and is_verified for query performance
- Query patterns use LIKE with LIMIT to ensure fast partial matches

**Testing**:
- Backend: Unit tests for query validation (username/email format)
- Backend: Integration tests for search endpoints, case-sensitivity, pagination, filtering
- Frontend: Widget tests for search bar debounce, result list rendering
- E2E: Full search flow - query entry, debounce behavior, result navigation to profile

**Target Platform**: Android/iOS (Flutter frontend), Linux/Docker (Shelf backend)  
**Project Type**: Mobile messaging app with backend API  
**Performance Goals**:
- Search query execution: <500ms (with proper indexes)
- Result display: <1s (frontend rendering)
- Search bar debounce: 500ms (prevent excessive API calls)
- Index verification: Query planner uses IndexScan, not sequential scan

**Constraints**:
- Username search: Alphanumeric + underscore + dash only, min 1 char, max 100 chars
- Email search: Valid email format required (contains @), min 3 chars, max 100 chars
- Results: Only verified users returned (is_verified = true filter)
- Pagination: Default limit 10 results, cap max 100 per request
- Privacy: Unverified users not discoverable via search
- Case-insensitive: "alice", "ALICE", "Alice" all find same user

**Scale/Scope**:
- 2 API endpoints (GET /search/username, GET /search/email)
- 1 backend service (SearchService with validation + query execution)
- 1 database migration (create 3 search indexes)
- 1 Riverpod provider (searchResultsProvider for fetching results)
- 1 Riverpod state notifier (searchFormNotifier for query state)
- 1 frontend screen (SearchScreen with search bar + result list)
- 2 frontend widgets (SearchBarWidget with debounce, SearchResultListWidget)
- HTTP service wrapper (frontend SearchService)

**Dependencies on Previous Specs**:
- Spec 001: Docker Compose, infrastructure
- Spec 002: User table with username, email, is_verified fields
- Spec 003: User authentication, JWT token handling, auth middleware
- Spec 005: User profile system (profile_picture_url for result display)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Security-First Principle (NON-NEGOTIABLE)

**Required**: Input validation, privacy enforcement, query performance, user enumeration prevention

**Design Decisions**:

1. **Validated Query Input** (IMPLEMENTED)
   - Username: Alphanumeric + underscore + dash only (no special chars for injection prevention)
   - Email: Must contain @ symbol, basic email format validation
   - Length: Min 1 char (username) / 3 chars (email), max 100 chars for both
   - Validation: Server-side only, not client-side hints
   - Rationale: Defense against SQL injection, prevent enumeration attacks via special characters

2. **Privacy Enforcement via Verification Filter** (IMPLEMENTED)
   - Unverified users: Excluded from search results (is_verified = true filter in query)
   - Confirmed users only: Only established users discoverable
   - Rationale: Prevents bot account enumeration, aligns with email verification workflow

3. **User Enumeration Prevention** (IMPLEMENTED)
   - Same response for existing/non-existing: Return empty list for both valid-but-no-match and invalid-query
   - No error differentiation: "No users found" for all zero-result cases
   - Rate limiting: Deferred to future (out of scope for MVP)
   - Rationale: Attacker cannot determine if username exists or not

4. **Query Performance & DoS Prevention** (IMPLEMENTED)
   - Indexes: Case-insensitive LOWER() indexes prevent full table scans
   - Result limits: Hard cap at 100 results per query (configurable, default 10)
   - Query timeout: HTTP request timeout (configured at server level)
   - Rationale: Prevent expensive queries from blocking other requests

5. **Authentication Enforcement** (IMPLEMENTED)
   - All searches require JWT authentication token
   - No public search without login
   - Rationale: Prevents unauthorized enumeration even if DB exposed

## Architecture Decision Record (ADR)

### ADR-001: Case-Insensitive Search via LOWER() Indexes

**Decision**: Use PostgreSQL LOWER() function with functional indexes instead of CITEXT type

**Rationale**:
- LOWER() is explicit and debuggable (query shows LOWER() in plan)
- Works cross-database (portable design if future migration needed)
- CITEXT has storage overhead; LOWER() is query-time only
- Compatible with LIKE operator for partial matching

**Implementation**:
```sql
CREATE INDEX idx_user_username_lower ON user(LOWER(username));
CREATE INDEX idx_user_email_lower ON user(LOWER(email));
```

**Alternative Considered**: CITEXT type extension (rejected - less portable, storage overhead)

### ADR-002: Debounce on Frontend, NOT Backend

**Decision**: Implement 500ms debounce in UI (SearchBarWidget), no backend debounce

**Rationale**:
- Reduces unnecessary API calls during typing (better UX + server load)
- Simple to implement in Flutter (Timer-based debounce)
- No state stored on server (stateless API design)
- User can always trigger immediate search via search button

**Implementation**:
```dart
// SearchBarWidget implements debounce timer
// Each keystroke cancels previous timer and starts new one
// After 500ms of no input, calls onQueryChanged()
```

**Alternative Considered**: Server-side request deduplication (rejected - complex, violates stateless design)

### ADR-003: Empty Result = Graceful, No Error Details

**Decision**: Return empty list [] for all zero-result cases (no differentiation in response)

**Rationale**:
- Prevents user enumeration (attacker cannot determine if user exists)
- Simplifies error handling (caller only checks list.length, not error codes)
- Aligns with UX (frontend shows same "No results found" message for all cases)

**Implementation**:
```dart
// Backend: searchByUsername("invalid@chars!") → [] (validation fails)
// Backend: searchByUsername("zzzznonexistent") → [] (no matches)
// Frontend: Both cases show "No results found" message
```

**Alternative Considered**: Different HTTP codes (400 vs 200 empty) - rejected, enables enumeration

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| Slow search due to missing indexes | High | High | Create indexes in Phase 1, test with EXPLAIN ANALYZE |
| SQL injection via special chars | Medium | Critical | Strict input validation (alphanumeric + _- only for username) |
| Unverified users in results | Medium | Medium | Add is_verified = true filter to all queries |
| Excessive API calls from rapid typing | Medium | Medium | Implement 500ms debounce in SearchBarWidget |
| User enumeration via response differences | Low | High | Return empty list for all zero-result cases |
| Timeout on large result sets | Low | Medium | LIMIT 100 max results, HTTP timeout |

## Implementation Timeline

**Phase 1 (Database)**: ~2 hours
- Create migration with 3 indexes (username, email, verified)
- Run and verify with EXPLAIN ANALYZE

**Phase 2 (Backend)**: ~8 hours
- SearchService with validation
- UserSearchResult model
- GET endpoints for username and email
- Integration test suite

**Phase 3 (Frontend)**: ~8 hours
- Riverpod providers (results + form state)
- SearchScreen with bar and list
- SearchBarWidget with debounce
- SearchResultListWidget
- Widget tests

**Phase 4 (Testing)**: ~6 hours
- E2E scenarios (5 user stories)
- Manual testing checklist
- Performance validation

**Total**: 24 hours sequential | ~12-14 hours parallelized with 2 developers

## Success Metrics

✅ All search queries execute in <500ms (verified via curl timing)  
✅ Database indexes used (EXPLAIN ANALYZE shows Index Scan, not Seq Scan)  
✅ Unverified users not in results (filter working)  
✅ Case-insensitive search (tested with uppercase/lowercase variants)  
✅ Debounce active (network tab shows 1 request per complete query, not per keystroke)  
✅ All 5 user stories pass (5 E2E scenarios)  
✅ Empty results handled gracefully (no error messages, user sees "No results found")  
✅ Search accessible from app navigation  
✅ Results navigable to user profiles
