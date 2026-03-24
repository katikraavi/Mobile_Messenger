# Phase 1 Design: Data Model & Schema

**Date**: March 11, 2026  
**Feature**: 004-email-verification-password-reset  
**Status**: Design Complete

## Data Model Overview

Email verification and password recovery data model extending the existing User, Chat, and Message entities with secure token management. Four new database entities track verification tokens, password reset tokens, and reset attempts with proper expiration, single-use semantics, and rate-limiting support.

## Entity Definitions

### Entity 1: VerificationToken

**Purpose**: Represents an email verification token for new user account activation
**Lifecycle**: Created on registration → Consumed when user clicks verification link → Expires 24 hours later

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique token record identifier
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User whose email is being verified
- `token_hash` (VARCHAR(255), UNIQUE, NOT NULL): SHA256 hash of verification token (raw token never stored)
- `expires_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Token expiration time (created_at + 24 hours)
- `used_at` (TIMESTAMP WITH TIME ZONE, nullable): When token was successfully used (null = unused)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT NOW()): Token creation timestamp (UTC)

**Relationships**:
- Many-to-One with User: Multiple verification tokens may exist for one user (resend scenario)
- One verification token belongs to exactly one user

**Constraints**:
- FOREIGN KEY user_id → User.id ON DELETE CASCADE: Remove tokens if user deleted
- UNIQUE(token_hash): Ensure no duplicate tokens in database
- NOT NULL: user_id, token_hash, expires_at, created_at
- CHECK (used_at IS NULL OR used_at >= created_at): Validation that used_at doesn't precede created_at
- CHECK (expires_at > created_at): Ensure expiration is in the future

**Indexes**:
- PRIMARY KEY on id
- UNIQUE INDEX on token_hash (fast token lookup by hash during verification)
- COMPOSITE INDEX on (user_id, created_at DESC) (find most recent token for user)
- INDEX on expires_at (cleanup queries for expired tokens)

**Design Notes**:
- Token itself (32 bytes, Base64URL) transmitted via email and frontend, never stored in DB
- Only SHA256 hash stored in database (prevents token exposure if DB compromised)
- Allows resending verification email (creates new token, invalidates old)
- Single `used_at` timestamp indicates verification, no explicit status field
- Prevents double-verification: Query returns error if `used_at IS NOT NULL`

---

### Entity 2: PasswordResetToken

**Purpose**: Represents a password reset token for account recovery
**Lifecycle**: Created when user requests password reset → Consumed when user sets new password → Expires 24 hours later

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique token record identifier
- `user_id` (UUID, FOREIGN KEY → User.id, NOT NULL): User resetting password
- `token_hash` (VARCHAR(255), UNIQUE, NOT NULL): SHA256 hash of password reset token
- `expires_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Token expiration time (created_at + 24 hours)
- `used_at` (TIMESTAMP WITH TIME ZONE, nullable): When token was successfully used (null = unused)
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT NOW()): Token creation timestamp (UTC)

**Relationships**:
- Many-to-One with User: Multiple password reset tokens may exist for one user (multiple requests)
- One token belongs to exactly one user

**Constraints**:
- FOREIGN KEY user_id → User.id ON DELETE CASCADE: Remove tokens if user deleted
- UNIQUE(token_hash): Ensure no duplicate tokens
- NOT NULL: user_id, token_hash, expires_at, created_at
- CHECK (used_at IS NULL OR used_at >= created_at): Temporal constraint
- CHECK (expires_at > created_at): Expiration in future

**Indexes**:
- PRIMARY KEY on id
- UNIQUE INDEX on token_hash (fast token lookup)
- COMPOSITE INDEX on (user_id, created_at DESC) (find most recent reset token for user)
- INDEX on expires_at (cleanup queries)

**Design Notes**:
- Identical structure to VerificationToken (separated for clarity and independent expiration policies)
- Same security model: Only hash stored, raw token transmitted via email
- Single-use: `used_at` timestamp marks consumption
- Failed reset attempts don't consume token (allow retry with same token)

---

### Entity 3: PasswordResetAttempt

**Purpose**: Tracks password reset requests for rate limiting enforcement
**Lifecycle**: Created on each password reset request → Automatically ignored after 60 minutes by time-windowed queries → Periodic deletion of entries older than 1 day

**Fields**:
- `id` (UUID, PRIMARY KEY): Unique attempt record identifier
- `email` (VARCHAR(255), NOT NULL): Email address requesting password reset
- `attempted_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, DEFAULT NOW()): When reset was requested (UTC)

**Relationships**:
- Reference (not FK) to User via email: Tracks attempts even if user not found
- Enables rate limiting without revealing user existence

**Constraints**:
- NOT NULL: email, attempted_at
- No UNIQUE constraint: Multiple attempts per email allowed (tracked by time)
- No FK: Allows tracking attempts for non-existent emails (user enumeration prevention)

**Indexes**:
- PRIMARY KEY on id
- COMPOSITE INDEX on (email, attempted_at DESC) (query: count attempts in last hour for rate limit check)
- INDEX on attempted_at (cleanup queries for old entries)

**Design Notes**:
- Tracks per-email (not IP) to avoid blocking legitimate multi-device users
- No explicit "attempt count" field: COUNT aggregation on time-windowed query
- Automatic expiration via queries (only consider last 60 minutes)
- Periodic cleanup job deletes entries older than 1 day (prevents unbounded table growth)
- Generic rate limiting: Same limit for all emails (no per-user customization)

---

### Entity 4: Users Table Update (Spec 002 Extension)

**Additional Field** (extends existing User entity from Spec 002):
- `verified_at` (TIMESTAMP WITH TIME ZONE, nullable): When email was verified (null = pending verification)

**Existing Fields** (from Spec 002, unchanged):
- `id` (UUID, PRIMARY KEY): User identifier
- `email` (VARCHAR(255), UNIQUE, NOT NULL): User's email
- `username` (VARCHAR(50), UNIQUE, NOT NULL): User's display name
- `password_hash` (VARCHAR(255), NOT NULL): bcrypt hash of password
- `email_verified` (BOOLEAN, DEFAULT false): Flag indicating verification status
- `profile_picture_url` (TEXT, nullable): URL to user's avatar
- `about_me` (TEXT, nullable): User's bio
- `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL): Account creation timestamp

**New Indexes** (for Spec 004):
- INDEX on email_verified (queries for unverified users, compliance checks)
- INDEX on verified_at (audit trials, find verified users in time range)

**Design Notes**:
- `verified_at` populated when verification token consumed
- Similar to Message.edited_at: Tracks timestamp of significant event
- Both `email_verified` (flag) and `verified_at` (timestamp) kept for:
  - Backward compatibility with Spec 003 queries
  - Audit trail (when did user verify)
- On registration: `email_verified = false`, `verified_at = NULL`
- On verification: `email_verified = true`, `verified_at = NOW()`
- Can extend later with `password_changed_at` for similar audit trail

---

## Relationships Diagram

```
User ──────────────┬─ (1:N) ──→ VerificationToken
                   │
                   ├─ (1:N) ──→ PasswordResetToken
                   │
                   ├─ (1:N) ──→ ChatMember ─ (N:1) ──→ Chat
                   │
                   ├─ (1:N) ──→ Message (sender_id)
                   │
                   ├─ (1:N) ──→ Invite (sender_id)
                   │
                   └─ (1:N) ──→ Invite (receiver_id)

PasswordResetAttempt
  └─ Tracks attempts by email (reference only, no FK)
```

---

## Key Constraints & Business Rules

### Token Expiration

**Verification Token**:
- Lifetime: 24 hours from creation
- Enforcement: Server checks `expires_at > NOW()` on verification
- Database: `expires_at = created_at + INTERVAL '24 hours'`
- Cleanup: Delete entries where `expires_at < NOW()` and `used_at IS NULL` (failed attempts kept briefly for debugging)

**Password Reset Token**:
- Lifetime: 24 hours from creation
- Same enforcement and cleanup as verification tokens

### Single-Use Semantics

**Verification Token**:
- First use: `used_at = NULL` → verification succeeds → `used_at = NOW()`
- Subsequent attempts: Check fails because `used_at IS NOT NULL`
- Resend: User can request new token; old token invalidated (by expiration)

**Password Reset Token**:
- First use: `used_at = NULL` → password updated → `used_at = NOW()`
- Subsequent attempts: Check fails because `used_at IS NOT NULL`
- User cannot reset twice with same token; must request new token

**Failed Attempts**:
- Verifying with wrong token: Token remains valid (can retry without resending email)
- Resetting with wrong password: Token remains valid (can retry same token)
- Resetting with invalid password (weakness): Token remains valid (can retry)

### Rate Limiting

**Password Reset Attempts**:
- Limit: 5 attempts per email per 60-minute window
- Query: `SELECT COUNT(*) FROM password_reset_attempts WHERE email = ? AND attempted_at > NOW() - INTERVAL '60 minutes'`
- Enforcement: If COUNT >= 5, return 429 Too Many Requests
- Recording: INSERT new record on each attempt (whether user verified or rate limited)
- Cleanup: Periodic job deletes entries older than 1 day

**No Rate Limit on Verification Email Resend**:
- Optional: Can add rate limit in future (e.g., max 5 resends per hour)
- Current design: No explicit limit; email service handles throttling

### Data Consistency

**On User Deletion**:
- Cascade deletes: VerificationToken, PasswordResetToken records deleted
- Orphaned attempts: PasswordResetAttempt entries remain (non-FK design)
- Impact: Minimal (entries deleted by cleanup job anyway)

**On Account Verification**:
- Atomic update: `UPDATE users SET email_verified = true, verified_at = NOW() WHERE id = ?`
- Token consumed: `UPDATE verification_tokens SET used_at = NOW() WHERE token_hash = ?`
- Order: Update user first, then mark token used (user update authoritative)

**On Password Reset**:
- Atomic updates in transaction:
  1. `UPDATE users SET password_hash = ?, email_verified = true, verified_at = NOW() WHERE id = ?`
  2. `UPDATE password_reset_tokens SET used_at = NOW() WHERE token_hash = ?`
  3. **Invalidate sessions**: Mark all JWT tokens for user as revoked (application layer)
  4. `INSERT INTO password_reset_attempts (email, attempted_at) VALUES (?, NOW())`
- Transaction ensures consistency; if step 1 fails, entire transaction rolled back

---

## Data Access Patterns

### Reading Patterns

**Verification Flow**:
```sql
-- 1. User clicks email link with token
SELECT id, user_id, expires_at, used_at 
FROM verification_tokens 
WHERE token_hash = SHA256(user_provided_token) AND expires_at > NOW();

-- 2. Check if already verified
SELECT id, email_verified, verified_at 
FROM users 
WHERE id = ? AND email_verified = true;
```

**Password Reset Flow**:
```sql
-- 1. User clicks reset link with token
SELECT id, user_id, expires_at, used_at 
FROM password_reset_tokens 
WHERE token_hash = SHA256(user_provided_token) AND expires_at > NOW();

-- 2. Rate limit check on password reset request
SELECT COUNT(*) 
FROM password_reset_attempts 
WHERE email = ? AND attempted_at > NOW() - INTERVAL '60 minutes';

-- 3. Find user by email (for reset request)
SELECT id, email, email_verified FROM users WHERE email = ?;
```

**Resend Verification Email**:
```sql
-- Find most recent unused token for user
SELECT id, token_hash, expires_at, used_at 
FROM verification_tokens 
WHERE user_id = ? 
ORDER BY created_at DESC 
LIMIT 1;

-- Optionally, check if user already verified
SELECT id, email_verified FROM users WHERE id = ?;
```

### Writing Patterns

**Create Verification Token**:
```sql
INSERT INTO verification_tokens (id, user_id, token_hash, expires_at, created_at)
VALUES (gen_random_uuid(), ?, SHA256(?), NOW() + INTERVAL '24 hours', NOW());
```

**Consume Verification Token**:
```sql
BEGIN TRANSACTION;
  UPDATE users 
  SET email_verified = true, verified_at = NOW() 
  WHERE id = (SELECT user_id FROM verification_tokens 
              WHERE token_hash = SHA256(?) AND expires_at > NOW() AND used_at IS NULL);
  
  UPDATE verification_tokens 
  SET used_at = NOW() 
  WHERE token_hash = SHA256(?) AND used_at IS NULL;
COMMIT;
```

**Track Password Reset Attempt**:
```sql
INSERT INTO password_reset_attempts (id, email, attempted_at)
VALUES (gen_random_uuid(), ?, NOW());
```

---

## Migration SQL

### Migration 007: Create verification_tokens table

```sql
CREATE TABLE IF NOT EXISTS verification_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CHECK (used_at IS NULL OR used_at >= created_at),
  CHECK (expires_at > created_at)
);

CREATE INDEX idx_verification_tokens_user_id 
  ON verification_tokens(user_id);

CREATE INDEX idx_verification_tokens_expires_at 
  ON verification_tokens(expires_at);

CREATE INDEX idx_verification_tokens_user_created 
  ON verification_tokens(user_id, created_at DESC);
```

### Migration 008: Create password_reset_tokens table

```sql
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CHECK (used_at IS NULL OR used_at >= created_at),
  CHECK (expires_at > created_at)
);

CREATE INDEX idx_password_reset_tokens_user_id 
  ON password_reset_tokens(user_id);

CREATE INDEX idx_password_reset_tokens_expires_at 
  ON password_reset_tokens(expires_at);

CREATE INDEX idx_password_reset_tokens_user_created 
  ON password_reset_tokens(user_id, created_at DESC);
```

### Migration 009: Create password_reset_attempts table

```sql
CREATE TABLE IF NOT EXISTS password_reset_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL,
  attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_password_reset_attempts_email_time 
  ON password_reset_attempts(email, attempted_at DESC);

CREATE INDEX idx_password_reset_attempts_time 
  ON password_reset_attempts(attempted_at);
```

### Migration 010: Add verified_at to users table

```sql
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX idx_users_email_verified 
  ON users(email_verified);

CREATE INDEX idx_users_verified_at 
  ON users(verified_at);
```

---

## Schema Evolution Notes

### Current Implementation (Spec 004)

- Simple token expiration with timestamp-based checks
- Single-use enforcement via `used_at` field
- Per-email rate limiting for password reset
- No session versioning (deferred to backend application layer)

### Future Enhancements

1. **Session Token Revocation** (security enhancement)
   - Add `user_token_version` to users table (incremented on password change)
   - Add `token_version` to JWT payload
   - Check match on each request (implements explicit session invalidation)

2. **Email Change** (feature enhancement)
   - Add `new_email` and `email_change_token` fields to users
   - Support verification of new email before applying change

3. **Account Recovery** (security enhancement)
   - Add `recovery_code` table (list of backup codes)
   - Add `recovery_question` and `recovery_answer_hash` fields

4. **Two-Factor Authentication** (security enhancement)
   - Add `2fa_enabled`, `2fa_method`, `2fa_secret` fields to users
   - Add `2fa_backup_codes` table for recovery

5. **Audit Trail** (compliance enhancement)
   - Add `auth_log` table (user_id, action, timestamp, IP, user_agent)
   - Log: registration, login, password change, email change

---

## Performance Considerations

### Query Optimization

**Fast Path** (Verification):
- `token_hash = ?`: UNIQUE INDEX lookup, O(log n)
- `expires_at > NOW()`: B-tree index, range scan fast

**Fast Path** (Rate Limit Check):
- Composite index `(email, attempted_at DESC)`: Optimized for window queries
- COUNT aggregation: INDEX scanning without full table scan

**Cleanup Queries**:
- `DELETE FROM verification_tokens WHERE expires_at < NOW() AND used_at IS NULL`
- Uses `expires_at` index, efficient range delete

### Scaling Considerations

**VerificationToken & PasswordResetToken**:
- Row size: ~150 bytes per token (id 16, user_id 16, hash 32, timestamps 24)
- Retention: 24 hours + optional archive = minimal storage
- Expected volume: O(daily active users) = ~1000s per day → manageable

**PasswordResetAttempt**:
- Row size: ~50 bytes per attempt (id 16, email 255 truncated, timestamp 16)
- Retention: 1 day (cleanup job deletes older)
- Expected volume: ~10% of users attempting per day = O(100s per day) → negligible

### Index Maintenance

- Indexes on timestamp columns (`created_at`, `attempted_at`) benefit from maintenance
- Run ANALYZE monthly to update statistics
- VACUUM to reclaim deleted rows (especially after cleanup jobs)

---

## Security Implications

### Token Storage

- Storing only hash prevents exposure if DB compromised
- Timing-safe comparison required (prevent timing attacks)
- Token transmission: HTTPS only (enforced by frontend/backend)

### Rate Limiting

- Per-email (not IP) provides security without blocking legitimate users
- 5 attempts/hour = attacker needs 2000+ hours to brute force (with reset endpoint)
- Exponential backoff in future (limit increases after violations)

### Account Activation

- Verification requirement enforced by `email_verified` check
- Protected endpoints check before allowing operations
- Prevents bots from bulk account creation

---

## Backward Compatibility

### Existing Queries (Spec 003 & Earlier)

- Spec 003 queries on `users` table unchanged (new columns added)
- Spec 002 Message/Chat queries unaffected
- Authentication middleware continues to validate JWT

### Migration Path

- New migrations ADD columns and tables (never DROP)
- Existing data untouched by new migrations
- Both `email_verified` (boolean) and `verified_at` (timestamp) populated consistently

---

## Testing Data Scenarios

### Test Setup

**Seed Data**:
```sql
-- Test user 1: Verified account
INSERT INTO users (id, email, username, password_hash, email_verified, verified_at, created_at)
VALUES ('uuid-verified-user', 'alice@example.com', 'alice', 'hash', true, NOW(), NOW());

-- Test user 2: Unverified account (pending verification)
INSERT INTO users (id, email, username, password_hash, email_verified, created_at)
VALUES ('uuid-unverified-user', 'bob@example.com', 'bob', 'hash', false, NOW());

-- Test verification token
INSERT INTO verification_tokens (id, user_id, token_hash, expires_at, created_at)
VALUES ('uuid-token-1', 'uuid-unverified-user', SHA256('raw_token_123'), NOW() + INTERVAL '24 hours', NOW());
```

### Test Scenarios

| Scenario | Setup | Query | Expected Result |
|----------|-------|-------|-----------------|
| Verify new account | Unverified user + valid token | SELECT... WHERE token_hash = SHA256('raw_token_123') | Token found, not expired, not used |
| Expired token | Token created 25 hours ago | SELECT... WHERE expires_at > NOW() | No results (expires_at < NOW()) |
| Already verified | Verified user, same token | SELECT... FROM users WHERE email_verified = true | User has email_verified=true |
| Rate limit | 5 attempts in last 60 min | SELECT COUNT(*) WHERE email = ? AND attempted_at > NOW()-'60 min' | COUNT = 5 (limit reached) |
| Reset attempt cleanup | Entry created 25 hours ago | SELECT... WHERE attempted_at > NOW()-'1 day' | Not included (older than 1 day) |

---

## Summary

Spec 004 data model adds four entities (VerificationToken, PasswordResetToken, PasswordResetAttempt, and Users.verified_at extension) supporting email verification and password recovery with strong security properties:

- **Single-use tokens**: Tracked via `used_at` timestamp
- **Expiration enforcement**: All tokens expire 24 hours after creation
- **Rate limiting**: Password reset limited to 5 per email per hour
- **Hash storage**: Token hashes stored, raw tokens transmitted only via email
- **User enumeration prevention**: Rate limiting per email enables risk-free enumeration checks
- **Audit trail**: `verified_at` timestamp supports compliance and analytics

The schema integrates seamlessly with existing User, Chat, Message entities while maintaining independence (no breaking changes to existing tables).
