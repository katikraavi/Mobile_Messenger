# Tasks: User Search (Spec 006)

**Spec Reference**: `/specs/006-user-search/`  
**Timeline**: 24 hours sequential | ~12-14 hours with 2 developers (parallelized)  
**MVP Scope**: Search by username + email → Result list → Navigate to profile (5 test scenarios from spec.md)  
**Team Size**: 2 developers (1 backend, 1 frontend) | Parallel execution recommended

---

## Overview

Implement user search functionality allowing users to find other users by username or email address. The system displays search results in a list with the ability to navigate to any user's profile. Features include query validation, result pagination, empty state handling, and search performance optimization via database indexing. Implementation spans 4 phases: database optimization (Phase 1), backend search service and endpoint (Phase 2), frontend search UI (Phase 3), and integration testing (Phase 4).

---

## Phase 1: Setup & Database Layer

**Duration**: ~2 hours  
**Responsible**: Backend Developer  
**Dependencies**: None (builds on existing Spec 002-003 infrastructure)  
**Parallel**: Not applicable (sequential database setup)

### Tasks

- [X] T001 Create migration 013_add_search_indexes.dart in backend/migrations/
  - Add LOWER() index on user.username for case-insensitive search: `CREATE INDEX idx_user_username_lower ON user(LOWER(username))`
  - Add LOWER() index on user.email for case-insensitive search: `CREATE INDEX idx_user_email_lower ON user(LOWER(email))`
  - Add index on user.is_verified for filtering active users: `CREATE INDEX idx_user_is_verified ON user(is_verified)`
  - Acceptance criteria: Indexes created successfully, no constraint violations, query planner uses indexes for LIKE queries

- [X] T002 Register migration in backend/lib/src/services/database_service.dart
  - Add migration 013 to the migrations list
  - Acceptance criteria: Migration file imported and registered; verify no duplicates in list

- [X] T003 Run migrations via docker-compose restart and verify in logs
  - Acceptance criteria: Verify no errors in migration output
  - Verify indexes exist: `\d user` shows idx_user_username_lower, idx_user_email_lower, idx_user_is_verified
  - Test index usage: Run EXPLAIN on sample search query, verify index is used (IndexScan or BitmapIndexScan)

---

## Phase 2: Backend Service Implementation

**Duration**: ~8 hours  
**Responsible**: Backend Developer  
**Dependencies**: T001, T002, T003 (Phase 1 complete)  
**Parallel Opportunities**: T005-T007 (models) can run in parallel with T004 (service); T008-T009 can be built concurrently

### Part A: Core Service

- [X] T004 Implement SearchService in backend/lib/src/services/search_service.dart with methods: searchByUsername(query, maxResults), searchByEmail(query, maxResults)
  - Method 1: searchByUsername(String query, int maxResults) → List<UserSearchResult>
    - Validate query: non-empty, min 1 char, max 100 chars, alphanumeric + underscore + dash only
    - Execute query: `SELECT id, username, email, profile_picture_url FROM user WHERE LOWER(username) LIKE LOWER(?) AND is_verified = true ORDER BY username ASC LIMIT ?`
    - Return: List of UserSearchResult objects, empty list if no matches
    - Error handling: Return empty list for validation failures, log errors
  - Method 2: searchByEmail(String query, int maxResults) → List<UserSearchResult>
    - Validate query: non-empty, valid email format (contains @), min 3 chars, max 100 chars
    - Execute query: `SELECT id, username, email, profile_picture_url FROM user WHERE LOWER(email) LIKE LOWER(?) AND is_verified = true ORDER BY email ASC LIMIT ?`
    - Return: List of UserSearchResult objects, exact match preferred (filter results)
    - Error handling: Return empty list for validation failures, log errors
  - Acceptance criteria: Both methods tested with valid/invalid queries; validation rejects invalid input; query uses indexes; max results respected

### Part B: Models & Serialization

- [X] T005 [P] Create UserSearchResult model in backend/lib/src/models/user_search_result.dart with properties: userId, username, email, profilePictureUrl, isPrivateProfile
  - Include toJson() and fromJson() methods for serialization
  - Acceptance criteria: Model serializes correctly to/from JSON; all properties optional except userId, username

- [X] T006 [P] Create SearchQuery model in backend/lib/src/models/search_query.dart with properties: query, type (username/email), maxResults
  - Include validation method validateQuery() → bool
  - Acceptance criteria: Serialization works; validation catches invalid queries

### Part C: Error Handling & Integration

- [X] T007 [P] Implement search validation and error handling in backend/lib/src/services/search_service.dart
  - Create SearchValidationException with message field
  - Implement validateUsername(query) → throws if invalid
  - Implement validateEmail(query) → throws if invalid
  - Acceptance criteria: All validation rules enforced; appropriate exceptions thrown; logged errors don't expose DB details

### Part D: API Endpoints

- [X] T008 [P] Implement GET /search/username endpoint in backend/lib/src/endpoints/search_handler.dart (authenticated, query param)
  - Route: GET /search/username?q={query}&limit=10
  - Request: query string params (q required, limit optional default 10)
  - Response: HTTP 200 with UserSearchResult[] JSON
  - Error handling: HTTP 400 if query invalid (empty, too long); HTTP 401 if not authenticated; HTTP 500 if DB error
  - Acceptance criteria: Endpoint responds correctly; validation enforced; error messages appropriate

- [X] T009 [P] Implement GET /search/email endpoint in backend/lib/src/endpoints/search_handler.dart (authenticated, query param)
  - Route: GET /search/email?q={query}&limit=10
  - Request: query string params (q required, limit optional default 10)
  - Response: HTTP 200 with UserSearchResult[] JSON
  - Error handling: HTTP 400 if query invalid; HTTP 401 if not authenticated; HTTP 500 if DB error
  - Acceptance criteria: Endpoint responds correctly; prioritizes exact email matches; handles partial matches

- [X] T010 Register SearchService and search endpoints with Shelf router in backend/lib/src/server.dart
  - Add middleware: require authentication for /search/* routes
  - Acceptance criteria: Routes registered; auth middleware applied; endpoints accessible

---

## Phase 3: Frontend Implementation

**Duration**: ~8 hours  
**Responsible**: Frontend Developer  
**Dependencies**: T008-T009 (backend endpoints ready)  
**Parallel Opportunities**: T011-T013 (providers/services) can be built in parallel; T014-T016 (UI) depends on T011-T013

### Part A: State Management

- [X] T011 [P] Create searchResultsProvider Riverpod FutureProvider in frontend/lib/features/search/providers/search_results_provider.dart
  - Provider parameters: query (String), searchType ('username' or 'email')
  - Fetch from backend: GET /search/{searchType}?q={query}&limit=20
  - Response: List<UserSearchResult>
  - Caching: No cache (fresh search on each query, or implement debounce)
  - Acceptance criteria: Provider fetches results correctly; handles errors; returns empty list for no results

- [X] T012 [P] Create searchFormNotifier Riverpod StateNotifier in frontend/lib/features/search/providers/search_form_provider.dart
  - State: query (String), searchType ('username' or 'email'), isSearching (bool)
  - Methods: setQuery(String), setSearchType(String), performSearch()
  - Acceptance criteria: State updates correctly; search type toggle works; form submission handled

- [X] T013 [P] Create SearchService (HTTP wrapper) in frontend/lib/features/search/services/search_service.dart
  - Methods: searchByUsername(query) → Future<List<UserSearchResult>>, searchByEmail(query) → Future<List<UserSearchResult>>
  - HTTP calls to backend endpoints, include auth token in headers
  - Error handling: throw exceptions on HTTP errors
  - Acceptance criteria: HTTP calls correct; auth tokens included; error handling works

### Part B: UI Screens

- [X] T014 Create SearchScreen in frontend/lib/features/search/screens/search_screen.dart
  - Layout: Search bar at top (text input + search type toggle)
  - Search bar behavior: Placeholder text "Search by username or email"
  - Search type toggle: Username / Email buttons (TabBar or RadioGroup pattern)
  - Results area: Results list below search bar, empty state if no results or no search
  - Acceptance criteria: UI displays correctly; search bar accepts input; toggle switches work

- [X] T015 [P] Create SearchResultListWidget in frontend/lib/features/search/widgets/search_result_list_widget.dart
  - Widget properties: results (List<UserSearchResult>), isLoading (bool), onTap callback
  - List item: Display username, email (if available), profile picture thumbnail, tap to navigate
  - Loading state: Show shimmer/progress indicator if isLoading=true
  - Empty state: Show message "No results found" if results empty and not loading
  - Acceptance criteria: List renders correctly; items are tappable; loading/empty states display

- [X] T016 [P] Create SearchBarWidget in frontend/lib/features/search/widgets/search_bar_widget.dart
  - Widget properties: onQueryChanged callback, onSearch callback, searchType, onSearchTypeChanged callback
  - Implements debounce: delay 500ms before calling onQueryChanged to avoid excessive API calls
  - Search icon on right: tap to trigger manual search
  - Clear icon in input when text present: tap to clear search
  - Acceptance criteria: Input accepts text; debounce working; callbacks triggered correctly; icons functional

### Part C: Navigation & Integration

- [X] T017 Wire SearchScreen into app navigation (via go_router in frontend/lib/app.dart)
  - Route path: /search
  - Add navigation option in main app (e.g., bottom nav or drawer)
  - Accepting context: SearchScreen receives optional initial query via route params
  - On result tap: Navigate to /profile/{userId}
  - Acceptance criteria: Routes work; navigation works; profile navigation works

---

## Phase 4: Integration & Testing

**Duration**: ~6 hours  
**Responsible**: Both Developers (collaborative testing)  
**Dependencies**: T001-T017 (all implementation phases complete)  
**Test Execution**: Backend & frontend tests in parallel, E2E sequential

### Part A: Database Optimization Tests

- [X] T018 Create unit tests in backend/test/unit/search_query_validation_test.dart for query validation:
  - Test validateUsername: valid queries (2-20 chars, alphanumeric+_-), invalid queries (empty, too long, special chars)
  - Test validateEmail: valid email format, invalid format (no @, incomplete), invalid length
  - Test QueryValidator.minLength and maxLength enforcement
  - Verify index usage: EXPLAIN ANALYZE on searches to confirm low cost

### Part B: Backend Integration Tests

- [X] T019 [P] Create integration test suite in backend/test/integration/search_integration_test.dart: GET /search/username happy path
  - Create 3 test users: "alice", "bob", "charlie"
  - Search "ali" → returns "alice" ✓
  - Search "ALI" (uppercase) → returns "alice" (case-insensitive) ✓
  - Search "cha" → returns "charlie" ✓
  - Search "nonexistent" → returns empty list []
  - Acceptance criteria: Case-insensitive search works; exact partial matches; empty list on no results

- [X] T020 [P] Create integration test: GET /search/email happy path
  - Create test users with emails: alice@example.com, bob@test.org
  - Search "alice@" → returns alice@example.com ✓
  - Search "alice@example.com" (exact) → returns exact match ✓
  - Search "bob@" → returns bob@test.org ✓
  - Search "notfound@" → returns empty list []
  - Acceptance criteria: Email search works; partial and exact matching; case-insensitive

- [X] T021 [P] Create integration test: Search validation and error cases
  - Empty query "" → HTTP 400 ✓
  - Query > 100 chars → HTTP 400 ✓
  - Invalid characters (e.g., alice<>) → HTTP 400 ✓
  - Valid query from unauthenticated client → HTTP 401 ✓
  - Acceptance criteria: All error cases handled; correct status codes

- [X] T022 [P] Create integration test: Search result filtering (verified users only)
  - Create unverified user "unverified_user"
  - Search "unverified" → returns empty list (filtered out) ✓
  - Verify verified user "verified_user" appears in results ✓
  - Acceptance criteria: Only verified users returned; unverified users filtered

- [X] T023 [P] Create integration test: Search result limits and pagination
  - Create 25 test users all matching "user"
  - Search with limit=10 → returns exactly 10 results ✓
  - Search with limit=5 → returns exactly 5 results ✓
  - Default limit=10 is applied when not specified
  - Results are sorted by username/email (consistent order) ✓
  - Acceptance criteria: Limit enforced; default applied; results sorted consistently

### Part C: Frontend Widget Tests

- [X] T024 [P] Create widget test for SearchScreen in frontend/test/features/search/screens/search_screen_test.dart
  - Verify search bar displays with placeholder text
  - Verify search type toggle shows two buttons: Username, Email
  - Verify switching toggle changes search type
  - Verify empty state text displays when no search yet
  - Acceptance criteria: All UI elements present; toggle works; empty state displays

- [X] T025 [P] Create widget test for SearchResultListWidget in frontend/test/features/search/widgets/search_result_list_widget_test.dart
  - Verify list displays with correct number of UserSearchResult items
  - Verify each item shows username, email, profile picture
  - Verify tapping item calls onTap callback with correct userId
  - Verify loading state shows progress indicator
  - Verify empty state shows "No results found" message
  - Acceptance criteria: List renders correctly; tap works; loading/empty states work

- [X] T026 [P] Create widget test for SearchBarWidget in frontend/test/features/search/widgets/search_bar_widget_test.dart
  - Verify text input accepts user input
  - Verify debounce: typing quickly triggers onQueryChanged only once (not on every keystroke)
  - Verify clear button appears when text present, disappears when empty
  - Verify search icon on right triggers onSearch callback
  - Verify clear button clears text
  - Acceptance criteria: Input works; debounce working; clear button functional; search icon works

### Part D: E2E & Manual Testing

- [X] T027 Execute E2E test scenario 1 (Search by username): Login → Open Search → Select "Username" → Type "alice" → Verify "alice" appears in results → Tap → Profile loads
  - Acceptance criteria: All steps work; profile navigation works

- [X] T028 Execute E2E test scenario 2 (Search by username - partial): Login → Search username "ali" → Verify results include "alice" and similar matches → Verify results sorted

- [X] T029 Execute E2E test scenario 3 (Search by email): Login → Switch to "Email" → Type "alice@example.com" → Verify exact match appears → Tap → Profile loads
  - Acceptance criteria: Email search works; exact match prioritized; navigation works

- [X] T030 Execute E2E test scenario 4 (Search by email - partial): Login → Switch to "Email" → Type "alice@" → Verify results show matching email addresses

- [X] T031 Execute E2E test scenario 5 (Empty results): Login → Search "zzzznotarealuser" → Verify empty state message "No results found" displays
  - Acceptance criteria: Empty state handled gracefully; message clear

- [X] T032 Manual testing checklist: 
  - (1) Search bar debounce prevents excessive API calls, verify network tab shows ~1 request per query
  - (2) Switching search type (Username ↔ Email) works smoothly without errors
  - (3) API errors (500, connection timeout) show error message to user, not crash
  - (4) Search results load in <1s (verify in Network tab)
  - (5) Tapping search result navigates to profile correctly and loads profile data
  - (6) Back button from profile returns to search results (state preserved)
  - (7) Case-insensitive search: "ALICE", "alice", "Alice" all find "alice" user
  - (8) Special characters in input rejected or sanitized (no SQL injection risk)

- [X] T033 [P] Performance validation testing:
  - Measure search by username latency (GET /search/username): Assert <500ms for typical query
  - Measure search by email latency (GET /search/email): Assert <500ms for typical query
  - Test with 1000+ users in database: verify query performance still acceptable
  - Use `time curl` with multiple runs: `time curl -H "Authorization: Bearer {token}" http://localhost:8081/search/username?q=alice`
  - Document results with timestamp; if any SLA exceeded, investigate index usage

---

## Dependencies & Execution Strategy

### Task Dependency Graph

```
Phase 1 (Sequential):
T001 → T002 → T003

Phase 2 (Mostly Parallel):
T003 → T004 (then parallel: T005, T006, T007)
       ↓
    T005, T006, T007 → T008, T009 (parallel)
       ↓
    T008, T009 → T010

Phase 3 (Mostly Parallel):
T010 → T011, T012, T013 (parallel) → T014
                                      ↓
                                T015, T016 (parallel)
                                      ↓
                                    T017

Phase 4 (Mostly Parallel):
T017 → T018-T023 (backend tests, parallel) ↓
    → T024-T026 (frontend tests, parallel) → T027-T032 (sequential E2E) → T033
```

### Parallel Execution Opportunities

**Backend Phase 2** (~8 hours → ~4-5 hours parallelized):
- Developer A: T004 (SearchService core logic)
- Developer B: T005, T006, T007 (models + validation) in parallel with Developer A
- Both: T008, T009 (endpoints) in parallel after service ready
- Together: T010 (integration)

**Frontend Phase 3** (~8 hours → ~4-5 hours parallelized):
- Developer A: T011, T012, T013 (providers/services) in parallel
- Developer B: T014 (SearchScreen) after providers ready
- Both: T015, T016 (list widget, search bar widget) in parallel
- Together: T017 (navigation integration)

**Testing Phase 4** (~6 hours → ~3-4 hours parallelized):
- Developer A: T018-T023 (backend tests, can run in parallel)
- Developer B: T024-T026 (frontend tests, can run in parallel)
- Together: T027-T033 (E2E scenarios, must run sequentially but fast)

---

## Task Checklist Format Reference

Each task follows this format:
```
- [ ] [TaskID] [P?] [Story?] Description with exact file path
```

**Components**:
- **[TaskID]**: T001-T033 (sequential within phase)
- **[P]**: Marks parallelizable tasks (can run alongside others in same phase)
- **[Story]**: Tags for specific user story (not used in this spec, included for consistency)
- **Description**: Clear action with file path

---

## Implementation Notes

### Phase 1: Database Setup

**Migrations Location**: `backend/migrations/`  
**Pattern**: Follow existing migrations (001-012) in the project  
**Verification Command**: 
```bash
docker-compose exec backend psql -U messenger_user -d messenger_db -c "\d user" | grep idx_user
# Verify: idx_user_username_lower, idx_user_email_lower, idx_user_is_verified exist
```

**Index Performance Verification**:
```bash
# Test index usage on username search
docker-compose exec backend psql -U messenger_user -d messenger_db -c "EXPLAIN ANALYZE SELECT id, username FROM user WHERE LOWER(username) LIKE LOWER('ali%') AND is_verified = true;"
# Verify: Execution uses Index Scan / BitmapIndex Scan (not Seq Scan)

# Test index usage on email search
docker-compose exec backend psql -U messenger_user -d messenger_db -c "EXPLAIN ANALYZE SELECT id, email FROM user WHERE LOWER(email) LIKE LOWER('alice%') AND is_verified = true;"
# Verify: Execution uses Index Scan
```

---

### Phase 2: Backend Implementation

**Service Location**: `backend/lib/src/services/search_service.dart`  
**Endpoints Location**: `backend/lib/src/endpoints/search_handler.dart`  
**Models Location**: `backend/lib/src/models/`

**Key Implementation Details**:
- All /search/* endpoints require auth middleware (user must be logged in)
- Only return results for is_verified = true users (privacy: unverified users not discoverable)
- Query validation: Username searches allow alphanumeric + underscore + dash, email searches require valid email format
- Max results default 10, configurable per request (cap at 100 max)
- Case-insensitive search via LOWER() function in SQL
- Error messages:
  - Empty/invalid query: `"Query must be between 1 and 100 characters"` (HTTP 400)
  - Invalid email format: `"Invalid email format"` (HTTP 400)
  - Not authenticated: `"Unauthorized"` (HTTP 401)
  - Server error: `"Unable to process search"` (HTTP 500, generic)

**Query Templates**:
```sql
-- Username search (case-insensitive)
SELECT id, username, email, profile_picture_url FROM user 
WHERE LOWER(username) LIKE LOWER(concat(?::text, '%')) AND is_verified = true 
ORDER BY username ASC LIMIT ?;

-- Email search (case-insensitive, prioritize exact match)
SELECT id, username, email, profile_picture_url FROM user 
WHERE LOWER(email) LIKE LOWER(concat(?::text, '%')) AND is_verified = true 
ORDER BY CASE WHEN LOWER(email) = LOWER(?) THEN 0 ELSE 1 END, email ASC LIMIT ?;
```

---

### Phase 3: Frontend Implementation

**Providers Location**: `frontend/lib/features/search/providers/`  
**Services Location**: `frontend/lib/features/search/services/`  
**Screens Location**: `frontend/lib/features/search/screens/`  
**Widgets Location**: `frontend/lib/features/search/widgets/`

**Riverpod Setup**:
```dart
// searchResultsProvider: FutureProvider<List<UserSearchResult>>
// Parameters: query (String), searchType ('username' or 'email')
// No TTL cache (fresh search each time)
// Triggered by: user clicking search or debounce timeout

// searchFormNotifier: StateNotifier<SearchFormState>
// Tracks: currentQuery, searchType, isSearching
// Methods: setQuery() updates state, performSearch() triggers provider

// UserSearchResult: userId, username, email, profilePictureUrl
```

**Debounce Pattern (in SearchBarWidget)**:
```dart
// Debounce user input: 500ms delay before calling onQueryChanged
// Prevents excessive API calls while user is typing
// Clear action immediately triggers new search
// Manual search icon also immediately triggers
```

**Navigation Pattern**:
```dart
// SearchScreen: /search
// From search result tap: context.push('/profile/${userId}')
// Back from profile: returns to /search (state preserved if using proper navigation)
```

---

### Phase 4: Integration & Testing

**Backend Test Location**: `backend/test/integration/search_integration_test.dart`  
**Frontend Test Location**: `frontend/test/features/search/`

**Test Execution**:
```bash
# Backend integration tests
cd backend && dart test test/integration/search_integration_test.dart

# Frontend widget tests
cd frontend && flutter test test/features/search/

# E2E testing: Use cURL for backend, manual Flutter app for frontend
```

**cURL Examples**:
```bash
# Search by username (authenticated)
curl -X GET "http://localhost:8081/search/username?q=alice&limit=10" \
  -H "Authorization: Bearer {token}"

# Search by username - case insensitive
curl -X GET "http://localhost:8081/search/username?q=ALICE&limit=10" \
  -H "Authorization: Bearer {token}"

# Search by email (authenticated)
curl -X GET "http://localhost:8081/search/email?q=alice@&limit=10" \
  -H "Authorization: Bearer {token}"

# Search by email - exact match
curl -X GET "http://localhost:8081/search/email?q=alice@example.com&limit=10" \
  -H "Authorization: Bearer {token}"

# Invalid query (empty)
curl -X GET "http://localhost:8081/search/username?q=&limit=10" \
  -H "Authorization: Bearer {token}"
# Expected: HTTP 400

# Unauthenticated request
curl -X GET "http://localhost:8081/search/username?q=alice&limit=10"
# Expected: HTTP 401
```

**Expected Test Results**:
- Scenario 1: Username search "alice" returns matching users ✓
- Scenario 2: Username search case-insensitive ✓
- Scenario 3: Email search "alice@" returns matching emails ✓
- Scenario 4: Email search "alice@example.com" exact match prioritized ✓
- Scenario 5: Empty search shows "No results found" message ✓
- Integration: Frontend debounce prevents excessive API calls ✓
- Integration: Search results navigable to profile ✓

---

## Success Criteria

1. ✅ **All 33 tasks completed** with all acceptance criteria met
2. ✅ **Database indexes** created successfully, query planner uses indexes
3. ✅ **Backend endpoints** respond correctly: GET /search/username, GET /search/email
4. ✅ **Search validation** working: rejects empty, invalid format, special characters
5. ✅ **Verified-only filtering** working: unverified users not in search results
6. ✅ **Frontend UI** displays search bar, toggle, result list
7. ✅ **Debounce working**: Network tab shows ~1 request per complete query, not per keystroke
8. ✅ **All 5 scenarios** from spec.md pass manual testing
9. ✅ **E2E flow** works: login → search username → see results → navigate to profile
10. ✅ **Performance** meets targets: search <500ms, result display <1s

---

## References & Resources

**Input Documents**:
- `/specs/006-user-search/spec.md` - Feature specification, 5 scenarios, search requirements

**Related Specs**:
- Spec 001: Docker Compose, infrastructure
- Spec 002: User table, database schema
- Spec 003: User authentication, JWT handling, auth middleware
- Spec 005: Profile system (reference for model patterns)

**Key Dependencies**:
- `backend`: `shelf_router`, `postgres`
- `frontend`: `flutter_riverpod`, `http`, `go_router`

**Performance Targets**:
- Search query: <500ms (with proper indexes)
- Results display: <1s
- Debounce default: 500ms
- Index verification: EXPLAIN ANALYZE should show Index Scan, not Seq Scan
