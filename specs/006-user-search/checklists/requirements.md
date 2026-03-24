# Testing Checklist: User Search (Spec 006)

**Feature**: User Search  
**Spec**: [006-user-search](../spec.md)  
**Date**: 2026-03-12

## Database Layer Tests

### Database Indexes
- [ ] Index `idx_user_username_lower` created on `user(LOWER(username))`
- [ ] Index `idx_user_email_lower` created on `user(LOWER(email))`
- [ ] Index `idx_user_is_verified` created on `user(is_verified)`
- [ ] EXPLAIN ANALYZE shows Index Scan (not Seq Scan) for test queries
- [ ] Query execution time <100ms for searches with 10k+ users
- [ ] No duplicate indexes exist

### Migration Verification
- [ ] Migration file `013_add_search_indexes.dart` created and registered
- [ ] Migration runs without errors during startup
- [ ] `docker-compose exec backend psql -U messenger_user -d messenger_db -c "\d user"` shows all indexes
- [ ] Indexes are usable (not in UNUSABLE state)

## Backend Service Tests

### SearchService Core Logic
- [ ] `searchByUsername("alice", 10)` returns matching users list
- [ ] `searchByUsername("ALICE", 10)` returns same results (case-insensitive)
- [ ] `searchByUsername("alice_smith", 10)` handles underscores correctly
- [ ] `searchByUsername("alice-user", 10)` handles dashes correctly
- [ ] `searchByUsername("", 10)` returns empty list (validation)
- [ ] `searchByUsername("alice<>", 10)` returns empty list (special chars rejected)
- [ ] `searchByUsername("a" * 101, 10)` returns empty list (>100 chars)
- [ ] `searchByUsername("alice", 100)` respects limit parameter
- [ ] `searchByEmail("alice@", 10)` returns matching emails
- [ ] `searchByEmail("alice@example.com", 10)` prioritizes exact match first
- [ ] `searchByEmail("alice", 10)` returns empty list (no @ fails validation)
- [ ] `searchByEmail("al", 10)` returns empty list (<3 chars fails)

### Database Query Behavior
- [ ] Only verified users (is_verified = true) in results
- [ ] Unverified users filtered out even if username matches
- [ ] Results sorted by username (username search) or email (email search)
- [ ] Exact email matches appear before partial matches (email search)
- [ ] Empty results return [] not null

### Error Handling
- [ ] Invalid query returns empty list (no exception thrown to caller)
- [ ] Database connection error returns empty list
- [ ] Errors logged to console (no info leak to client)

## API Endpoint Tests

### GET /search/username
- [ ] Endpoint accessible at `http://localhost:8081/search/username`
- [ ] Requires `q` query parameter (HTTP 400 if missing)
- [ ] Optional `limit` parameter (defaults to 10)
- [ ] Returns HTTP 200 with JSON array on success
- [ ] Returns HTTP 400 if query parameter invalid
- [ ] Returns HTTP 401 if no auth token provided
- [ ] Returns HTTP 401 if auth token invalid/expired
- [ ] Response schema matches UserSearchResult (userId, username, email, profilePictureUrl, isPrivateProfile)
- [ ] Response times <500ms (measured with curl timing)

### GET /search/email
- [ ] Endpoint accessible at `http://localhost:8081/search/email`
- [ ] Requires `q` query parameter (HTTP 400 if missing)
- [ ] Optional `limit` parameter (defaults to 10)
- [ ] Returns HTTP 200 with JSON array on success
- [ ] Returns HTTP 400 if query parameter invalid (no @)
- [ ] Returns HTTP 401 if not authenticated
- [ ] Response schema matches UserSearchResult
- [ ] Exact matches prioritized (appear before partial matches)
- [ ] Response times <500ms

### Authentication & Authorization
- [ ] Both endpoints require Bearer token in Authorization header
- [ ] Missing Authorization header returns HTTP 401
- [ ] Invalid/expired token returns HTTP 401
- [ ] Endpoint doesn't expose user data without auth

### Pagination & Limits
- [ ] Default limit = 10 when not specified
- [ ] Limit parameter respected (limit=5 returns 5 results)
- [ ] Max limit = 100 enforced (limit=200 capped at 100)
- [ ] Limit < 1 returns HTTP 400
- [ ] Invalid limit value returns HTTP 400

## Frontend Widget Tests

### SearchBarWidget
- [ ] Widget renders with text input field
- [ ] Placeholder text displays "Search by username or email"
- [ ] Username / Email toggle buttons display
- [ ] Toggling search type clears previous query
- [ ] Text input accepts user typing
- [ ] Clear button appears when text present
- [ ] Clear button removes text
- [ ] Debounce: Single request after 500ms idle (not per keystroke)
- [ ] Debounce: Rapid typing triggers only final request
- [ ] Manual search button triggers immediate search
- [ ] onQueryChanged callback called only after debounce timeout
- [ ] onSearchTypeChanged callback called on toggle click

### SearchResultListWidget
- [ ] Widget renders list of results
- [ ] Each result item shows username, email, profile picture
- [ ] Result item is tappable
- [ ] Empty state shows "No results found" message
- [ ] Loading state shows progress indicator / shimmer
- [ ] Loading state animates smoothly
- [ ] Result items have correct onTap callback
- [ ] Multiple results display in correct order

### SearchScreen Integration
- [ ] Search bar displays at top
- [ ] Result list displays below search bar
- [ ] Empty state shows before any search
- [ ] Results update when query changes
- [ ] Loading state shows while fetching
- [ ] Results display after fetch completes
- [ ] Error state shows gracefully
- [ ] Tapping result navigates to profile screen

## Integration Tests (E2E)

### Scenario 1: Username Search - Exact Match
- [ ] Login with valid user
- [ ] Open Search screen
- [ ] Toggle to "Username" search type
- [ ] Type "alice"
- [ ] User "alice" appears in results
- [ ] Click "alice" result
- [ ] Navigates to alice's profile
- [ ] Profile data loads correctly

### Scenario 2: Username Search - Partial Match
- [ ] Login
- [ ] Activate Username search
- [ ] Type "ali"
- [ ] Results show all users with "ali" in username (alice, alice_smith, etc.)
- [ ] Results sorted by username
- [ ] Multiple results displayed

### Scenario 3: Email Search - Exact Match
- [ ] Login
- [ ] Toggle to "Email" search type
- [ ] Type "alice@example.com"
- [ ] Exact match appears first in results
- [ ] Click result
- [ ] Navigates to correct profile

### Scenario 4: Email Search - Partial Match
- [ ] Login
- [ ] Activate Email search
- [ ] Type "alice@"
- [ ] Results show all emails starting with "alice@"
- [ ] Sorted by domain after matching prefix

### Scenario 5: Empty Results
- [ ] Login
- [ ] Search for "zzzznonexistentuser"
- [ ] Results show "No results found" message
- [ ] No error displayed
- [ ] User can search again

## Manual Testing Checklist

### Network & Performance
- [ ] Network tab shows 1 request per complete query (debounce working)
- [ ] Network tab shows 0 requests while typing mid-query
- [ ] Search response time <500ms (network tab timing)
- [ ] Results display <1s after response received
- [ ] No duplicate requests sent

### User Experience
- [ ] Search bar has clear visual focus when active
- [ ] Placeholder text helpful and visible
- [ ] Toggle between search types is intuitive
- [ ] Typing in search bar feels responsive (no lag)
- [ ] Empty results message is clear and helpful
- [ ] Result items clickable and responsive
- [ ] Loading indicator visible and appropriate
- [ ] Error messages clear (if any shown)

### Case Sensitivity
- [ ] "alice" finds user with username "alice"
- [ ] "ALICE" finds user with username "alice" (case-insensitive)
- [ ] "Alice" finds user with username "alice" (case-insensitive)
- [ ] "ALI" finds users starting with "ali" (case-insensitive partial)

### Search Type Switching
- [ ] Switching from Username to Email clears query
- [ ] Switching back to Username clears query
- [ ] Toggle visually shows current selection
- [ ] No errors when switching rapidly

### Privacy & Security
- [ ] Private profile users still appear in search results
- [ ] Clicking private profile navigates to profile (privacy checks on profile, not search)
- [ ] Unverified users do NOT appear in search results
- [ ] Special characters in input are rejected (no crash)
- [ ] Very long queries are rejected (no crash)
- [ ] Cannot search without authentication (401 error)

### Edge Cases
- [ ] Search with minimum query (1 char username, 3 chars email)
- [ ] Search with maximum query (100 chars)
- [ ] Search with numbers in username (alice123)
- [ ] Search with underscores (alice_smith)
- [ ] Search with dashes (alice-smith)
- [ ] Search with apostrophe (should fail gracefully)
- [ ] Search with emoji (should fail gracefully)
- [ ] Rapid search type toggles don't crash app
- [ ] Network disconnection handled gracefully

## Performance Validation

### Backend Query Performance
- [ ] Test: `EXPLAIN ANALYZE SELECT id, username FROM user WHERE LOWER(username) LIKE LOWER('ali%') AND is_verified = true LIMIT 10`
- [ ] Expected: Index Scan or Bitmap Index Scan (not Seq Scan)
- [ ] Expected: Rows < 20 (short circuit on LIMIT 10)
- [ ] Expected: Planning time + Execution time < 5ms

### End-to-End Latency (with 10k+ users)
- [ ] Username search: <500ms (curl timing)
- [ ] Email search: <500ms (curl timing)
- [ ] Result render: <1s (UI measurement)
- [ ] Total user perceived latency: <1.5s

### Load Testing (Future - Optional)
- [ ] 100 concurrent search requests: No timeouts
- [ ] Server CPU usage stays <80% during load
- [ ] Database connection pool doesn't exhaust
- [ ] Slow queries monitored and logged

## Accessibility Checks

- [ ] Search input field has accessible label
- [ ] Toggle buttons are keyboard accessible
- [ ] Result list is screen-reader friendly
- [ ] Errors announced clearly
- [ ] Loading states announced
- [ ] Color contrast meets WCAG AA standards

## Documentation Verification

- [ ] README updated with search feature description
- [ ] API documentation (OpenAPI) is accurate
- [ ] Code comments explain debounce logic
- [ ] Error messages documented
- [ ] Testing instructions documented
- [ ] Limitations documented (e.g., "unverified users excluded")

## Sign-Off

**Tested By**: ________________  
**Date**: ________________  
**Notes**: ________________

- [ ] All tests passed
- [ ] All blockers resolved
- [ ] Feature ready for release
