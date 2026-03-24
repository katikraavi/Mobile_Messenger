# Phase 1 Design: Data Model

**Date**: 2026-03-12  
**Feature**: 006-user-search  
**Status**: Design Complete

## Data Model Overview

User search relies on existing User entity from Spec 002, extended with database indexes for efficient case-insensitive search. No new entities required; all search logic is query-layer optimization.

## Entity Extensions

### Entity: User (Indexed for Search)

**Purpose**: Existing User entity from Spec 002, optimized with search indexes

**Used Fields** (no changes to User table):
- `id` (UUID): User identifier
- `username` (VARCHAR): Username for search (case-insensitive LOWER() index)
- `email` (VARCHAR): Email for search (case-insensitive LOWER() index)
- `is_verified` (BOOLEAN): Filter to show only verified users
- `profile_picture_url` (TEXT, nullable): Display profile picture in search results
- `created_at` (TIMESTAMP): Metadata, not indexed for search

**New Indexes** (for search optimization):
```sql
-- Case-insensitive username search index
CREATE INDEX IF NOT EXISTS idx_user_username_lower ON "user"(LOWER(username));

-- Case-insensitive email search index
CREATE INDEX IF NOT EXISTS idx_user_email_lower ON "user"(LOWER(email));

-- Verified users only (filter index)
CREATE INDEX IF NOT EXISTS idx_user_is_verified ON "user"(is_verified);

-- Combined: username search with verified filter
-- Query planner uses this for: WHERE LOWER(username) LIKE ... AND is_verified = true
```

**Index Rationale**:
- `LOWER(username)`: Functional index enables case-insensitive search without CITEXT overhead
- `LOWER(email)`: Same as username, for email search queries
- `is_verified`: Single-column index helps filter unverified users (can be combined with username/email index)
- PostgreSQL query planner will use bitmap index scans combining multiple indexes for complex WHERE clauses

**Query Examples**:
```sql
-- Username search (case-insensitive)
-- Uses: idx_user_username_lower, idx_user_is_verified (bitmap scan)
SELECT id, username, email, profile_picture_url 
FROM "user" 
WHERE LOWER(username) LIKE LOWER('ali%') AND is_verified = true 
ORDER BY username ASC 
LIMIT 10;

-- Email search (case-insensitive, exact match preferred)
-- Uses: idx_user_email_lower, idx_user_is_verified
SELECT id, username, email, profile_picture_url 
FROM "user" 
WHERE LOWER(email) LIKE LOWER('alice@%') AND is_verified = true 
ORDER BY CASE WHEN LOWER(email) = LOWER('alice@example.com') THEN 0 ELSE 1 END, 
         email ASC 
LIMIT 10;

-- Index usage verification
EXPLAIN ANALYZE SELECT id, username FROM "user" 
WHERE LOWER(username) LIKE LOWER('ali%') AND is_verified = true;
-- Expected: Bitmap Index Scan / Index Scan on idx_user_username_lower
```

**Index Performance**:
- Without indexes: Sequential scan on full user table (O(n) complexity)
- With indexes: Bitmap scan combining idx_user_username_lower + idx_user_is_verified (O(log n) complexity)
- Expected improvement: 10-100x faster on 10k+ user databases

**Constraints** (no changes needed):
- User table constraints from Spec 002 remain unchanged
- No new constraints required for search feature

**No New Tables**: Search feature uses existing User table only

## Migration File

**File**: `backend/migrations/013_add_search_indexes.dart`

**Purpose**: Create case-insensitive search indexes on User table

**Operations**:
1. Create LOWER() index on username
2. Create LOWER() index on email
3. Create index on is_verified

**Rollback**: Drop all three indexes (safe - no data loss)

**Idempotency**: Uses `IF NOT EXISTS` to handle re-runs

## Implementation Notes

### Index Creation Strategy

**Phase 1 Timing**: Execute migration during deployment (non-blocking)

**Performance During Creation**:
- Index creation locks write operations briefly on that column
- For large user tables (1M+ rows), create with `CONCURRENTLY` option to avoid locks
- Current project scale (<10k users) allows synchronous creation

**Verification Commands**:
```bash
# List all indexes on user table
psql -U messenger_user -d messenger_db -c "\d user" | grep idx_

# Check index usage with EXPLAIN
psql -U messenger_user -d messenger_db -c "EXPLAIN (ANALYZE, BUFFERS) SELECT id, username FROM \"user\" WHERE LOWER(username) LIKE LOWER('ali%') AND is_verified = true LIMIT 10;"

# Expected output: "Index Scan using idx_user_username_lower" or "Bitmap Index Scan"
```

### Query Optimization

**PostgreSQL Query Planner**:
- Planner automatically combines idx_user_username_lower and idx_user_is_verified
- Bitmap index scan most efficient for multi-column WHERE clauses
- LIMIT 10 ensures quick termination after finding first 10 matches

**Case Sensitivity Behavior**:
- LOWER() function normalizes both search query and column value
- Example: WHERE LOWER(username) LIKE LOWER('ALI%') becomes WHERE lower(username) LIKE 'ali%'
- Works across all Unicode characters (not just ASCII)

## Scalability Considerations

### Current Scale (Target Users)
- Estimated 10k-100k users at launch
- Indexes add ~5-10MB per 10k users (typical BTREE overhead)
- Query response <500ms expected with these indexes

### Future Scale (100k+ users)
- Indexes remain performant up to 1M+ users
- If search queries become bottleneck:
  - Consider full-text search (PostgreSQL tsearch2 extension)
  - Consider denormalized search table (if needed for features like "trending searches")
  - Consider search engine integration (Elasticsearch, Meilisearch) for advanced features

### Index Maintenance
- Indexes automatically maintained by PostgreSQL VACUUM process
- No manual index rebuilding required for normal operations
- Monitor disk space for index growth (alert if >20% growth/month indicates issue)

## Test Scenarios for Verification

### Scenario 1: Case-Insensitive Search Works
```
Setup: User with username "alice" in verified state
Test: Search LOWER(username) LIKE LOWER('ALICE%')
Expected: Returns alice user
Verification: Uses idx_user_username_lower index (EXPLAIN output)
```

### Scenario 2: Unverified Users Filtered
```
Setup: Two users - alice (verified), bob (unverified)
Test: Search username LIKE 'bob%' with is_verified = true filter
Expected: Returns empty list (bob excluded)
Verification: Query uses idx_user_is_verified filter
```

### Scenario 3: Partial Email Match
```
Setup: Users with emails alice@example.com, alice@test.org, bob@example.com
Test: Search LOWER(email) LIKE LOWER('alice@%')
Expected: Returns both alice users, sorted by email
Verification: Uses idx_user_email_lower, correct sorting
```

### Scenario 4: Index Performance
```
Setup: 10k+ test users in database
Test: Search username query execution time
Expected: <100ms (with index) vs >1000ms (without index)
Verification: EXPLAIN ANALYZE shows Index Scan, buffer hits >90%
```

## Migration Rollback Plan

If search indexes cause performance regression:

```bash
# Disable indexes temporarily (removes from query planner, doesn't delete)
ALTER INDEX idx_user_username_lower UNUSABLE;

# Or drop permanently
DROP INDEX IF EXISTS idx_user_username_lower;
DROP INDEX IF EXISTS idx_user_email_lower;
DROP INDEX IF EXISTS idx_user_is_verified;

# Re-create if needed
# (can re-run migration 013)
```

**Recoverability**: Indexes are metadata only - dropping doesn't affect user data. Safe to drop and recreate.
